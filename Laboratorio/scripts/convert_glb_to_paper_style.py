#!/usr/bin/env python3
"""Convert a binary glTF model into a paper-cutout/cel shaded style.

This script intentionally avoids Blender so it can run in a minimal local
Python install. It edits GLB data directly: material colors, vertex positions,
vertex colors, and outline shell primitives.
"""

from __future__ import annotations

import argparse
import colorsys
import json
import math
import struct
from pathlib import Path
from typing import Any


JSON_CHUNK = b"JSON"
BIN_CHUNK = b"BIN\x00"

ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963

FLOAT = 5126
UNSIGNED_BYTE = 5121
UNSIGNED_SHORT = 5123
UNSIGNED_INT = 5125

COMPONENTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}

STRUCT_FORMATS = {
    FLOAT: ("f", 4),
    UNSIGNED_BYTE: ("B", 1),
    UNSIGNED_SHORT: ("H", 2),
    UNSIGNED_INT: ("I", 4),
}


PAPER_PALETTE = {
    "skin": (1.0, 0.70, 0.40, 1.0),
    "boots": (0.76, 0.36, 0.08, 1.0),
    "pants": (0.88, 0.43, 0.06, 1.0),
    "material.001": (0.30, 0.22, 0.04, 1.0),
    "material.002": (0.035, 0.030, 0.026, 1.0),
    "material.003": (0.94, 0.48, 0.08, 1.0),
    "material.004": (0.97, 0.93, 0.82, 1.0),
    "material.005": (0.05, 0.38, 0.09, 1.0),
    "material.007": (0.03, 0.31, 0.08, 1.0),
    "material.022": (1.0, 0.86, 0.24, 1.0),
    "material.020": (0.96, 0.78, 0.19, 1.0),
    "material.012": (0.04, 0.54, 0.12, 1.0),
}


def align4(value: int) -> int:
    return (value + 3) & ~3


def parse_glb(path: Path) -> tuple[dict[str, Any], bytearray]:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("File is too small to be a GLB.")

    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError("Expected a glTF 2.0 binary file.")
    if total_length != len(data):
        raise ValueError("GLB header length does not match file size.")

    offset = 12
    gltf: dict[str, Any] | None = None
    binary = bytearray()

    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_length]
        offset += chunk_length

        if chunk_type == JSON_CHUNK:
            gltf = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\x00"))
        elif chunk_type == BIN_CHUNK:
            binary = bytearray(chunk)

    if gltf is None:
        raise ValueError("GLB has no JSON chunk.")
    if not binary:
        raise ValueError("GLB has no binary buffer chunk.")
    if len(gltf.get("buffers", [])) != 1:
        raise ValueError("This converter expects one embedded binary buffer.")

    return gltf, binary


def write_glb(path: Path, gltf: dict[str, Any], binary: bytearray) -> None:
    gltf["buffers"][0]["byteLength"] = len(binary)

    json_bytes = json.dumps(gltf, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
    json_padding = align4(len(json_bytes)) - len(json_bytes)
    bin_padding = align4(len(binary)) - len(binary)

    json_chunk = json_bytes + b" " * json_padding
    bin_chunk = bytes(binary) + b"\x00" * bin_padding
    total_length = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)

    with path.open("wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, total_length))
        handle.write(struct.pack("<I4s", len(json_chunk), JSON_CHUNK))
        handle.write(json_chunk)
        handle.write(struct.pack("<I4s", len(bin_chunk), BIN_CHUNK))
        handle.write(bin_chunk)


def accessor_layout(gltf: dict[str, Any], accessor_index: int) -> tuple[dict[str, Any], int, int, str, int, int, int]:
    accessor = gltf["accessors"][accessor_index]
    if accessor.get("sparse"):
        raise ValueError("Sparse accessors are not supported by this converter.")
    if "bufferView" not in accessor:
        raise ValueError(f"Accessor {accessor_index} has no bufferView.")

    view = gltf["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    if component_type not in STRUCT_FORMATS:
        raise ValueError(f"Accessor {accessor_index} uses unsupported component type {component_type}.")
    if accessor["type"] not in COMPONENTS:
        raise ValueError(f"Accessor {accessor_index} uses unsupported type {accessor['type']}.")

    fmt, component_size = STRUCT_FORMATS[component_type]
    component_count = COMPONENTS[accessor["type"]]
    item_size = component_size * component_count
    stride = view.get("byteStride", item_size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return accessor, accessor["count"], component_count, fmt, component_size, stride, offset


def read_accessor(gltf: dict[str, Any], binary: bytearray, accessor_index: int) -> list[tuple[float, ...]]:
    accessor, count, component_count, fmt, _component_size, stride, offset = accessor_layout(gltf, accessor_index)
    item_format = "<" + fmt * component_count
    item_size = struct.calcsize(item_format)

    values: list[tuple[float, ...]] = []
    for i in range(count):
        base = offset + i * stride
        values.append(struct.unpack_from(item_format, binary, base))
    return values


def write_accessor(gltf: dict[str, Any], binary: bytearray, accessor_index: int, values: list[tuple[float, ...]]) -> None:
    accessor, count, component_count, fmt, _component_size, stride, offset = accessor_layout(gltf, accessor_index)
    if len(values) != count:
        raise ValueError(f"Accessor {accessor_index} expected {count} values, got {len(values)}.")

    item_format = "<" + fmt * component_count
    for i, value in enumerate(values):
        if len(value) != component_count:
            raise ValueError(f"Accessor {accessor_index} value {i} has the wrong component count.")
        struct.pack_into(item_format, binary, offset + i * stride, *value)

    if component_count > 1:
        mins = [min(value[c] for value in values) for c in range(component_count)]
        maxs = [max(value[c] for value in values) for c in range(component_count)]
        accessor["min"] = mins
        accessor["max"] = maxs
    else:
        scalar_values = [value[0] for value in values]
        accessor["min"] = [min(scalar_values)]
        accessor["max"] = [max(scalar_values)]


def append_accessor(
    gltf: dict[str, Any],
    binary: bytearray,
    values: list[tuple[float, ...]],
    *,
    component_type: int,
    type_name: str,
    target: int | None = None,
) -> int:
    if component_type not in STRUCT_FORMATS:
        raise ValueError(f"Unsupported component type {component_type}.")
    if type_name not in COMPONENTS:
        raise ValueError(f"Unsupported accessor type {type_name}.")

    component_count = COMPONENTS[type_name]
    fmt, _component_size = STRUCT_FORMATS[component_type]
    item_format = "<" + fmt * component_count

    padding = align4(len(binary)) - len(binary)
    if padding:
        binary.extend(b"\x00" * padding)

    offset = len(binary)
    for value in values:
        if len(value) != component_count:
            raise ValueError(f"Expected {component_count} components, got {len(value)}.")
        binary.extend(struct.pack(item_format, *value))

    byte_length = len(binary) - offset
    view: dict[str, Any] = {
        "buffer": 0,
        "byteOffset": offset,
        "byteLength": byte_length,
    }
    if target is not None:
        view["target"] = target

    gltf.setdefault("bufferViews", []).append(view)
    view_index = len(gltf["bufferViews"]) - 1

    accessor: dict[str, Any] = {
        "bufferView": view_index,
        "componentType": component_type,
        "count": len(values),
        "type": type_name,
    }

    if values:
        if component_count > 1:
            accessor["min"] = [min(value[c] for value in values) for c in range(component_count)]
            accessor["max"] = [max(value[c] for value in values) for c in range(component_count)]
        else:
            accessor["min"] = [min(value[0] for value in values)]
            accessor["max"] = [max(value[0] for value in values)]

    gltf.setdefault("accessors", []).append(accessor)
    return len(gltf["accessors"]) - 1


def source_color(material: dict[str, Any]) -> tuple[float, float, float, float]:
    pbr = material.get("pbrMetallicRoughness", {})
    color = pbr.get("baseColorFactor", [0.75, 0.75, 0.75, 1.0])
    return tuple(float(x) for x in color[:4])  # type: ignore[return-value]


def stylize_color(material: dict[str, Any]) -> tuple[float, float, float, float]:
    name = material.get("name", "").lower()
    if name in PAPER_PALETTE:
        return PAPER_PALETTE[name]

    r, g, b, a = source_color(material)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = min(1.0, s * 1.18 + 0.08)
    v = min(1.0, v * 1.10 + 0.05)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (r, g, b, a)


def style_materials(gltf: dict[str, Any]) -> int:
    extensions_used = set(gltf.get("extensionsUsed", []))
    extensions_used.add("KHR_materials_unlit")
    gltf["extensionsUsed"] = sorted(extensions_used)

    for material in gltf.get("materials", []):
        color = stylize_color(material)
        pbr = material.setdefault("pbrMetallicRoughness", {})
        pbr["baseColorFactor"] = [round(c, 5) for c in color]
        pbr["metallicFactor"] = 0.0
        pbr["roughnessFactor"] = 1.0
        material["doubleSided"] = True
        material.setdefault("extensions", {})["KHR_materials_unlit"] = {}
        material["extras"] = {
            **material.get("extras", {}),
            "paperStyle": "matte flat paper color",
        }

    outline_material = {
        "name": "paper_ink_outline",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.018, 0.014, 0.012, 1.0],
            "metallicFactor": 0.0,
            "roughnessFactor": 1.0,
        },
        "extensions": {"KHR_materials_unlit": {}},
        "extras": {"paperStyle": "single-sided inverted ink outline shell"},
    }
    gltf.setdefault("materials", []).append(outline_material)
    return len(gltf["materials"]) - 1


def noise01(seed: int) -> float:
    seed = (seed ^ 0x45D9F3B) & 0xFFFFFFFF
    seed = (seed * 0x45D9F3B) & 0xFFFFFFFF
    seed = (seed ^ (seed >> 16)) & 0xFFFFFFFF
    return seed / 0xFFFFFFFF


def paper_vertex_colors(positions: list[tuple[float, ...]], material_index: int) -> list[tuple[float, float, float, float]]:
    colors: list[tuple[float, float, float, float]] = []
    for index, position in enumerate(positions):
        x, y, z = position[:3]
        low_frequency = 0.5 + 0.5 * math.sin(x * 11.3 + y * 7.7 + z * 5.9 + material_index)
        grain = noise01(index * 977 + material_index * 101)
        shade = 0.88 + 0.09 * low_frequency + 0.035 * grain
        colors.append((shade, shade, shade, 1.0))
    return colors


def normalize(vector: tuple[float, ...]) -> tuple[float, float, float]:
    x, y, z = vector[:3]
    length = math.sqrt(x * x + y * y + z * z)
    if length <= 1e-8:
        return (0.0, 0.0, 1.0)
    return (x / length, y / length, z / length)


def transform_position(
    position: tuple[float, ...],
    *,
    center: list[float],
    extents: list[float],
    depth_axis: int,
    width_axis: int,
    depth_scale: float,
    bend_strength: float,
) -> tuple[float, float, float]:
    styled = [float(position[0]), float(position[1]), float(position[2])]
    styled[depth_axis] = center[depth_axis] + (styled[depth_axis] - center[depth_axis]) * depth_scale

    width_extent = max(extents[width_axis], 1e-6)
    width_phase = (styled[width_axis] - center[width_axis]) / width_extent
    styled[depth_axis] += math.sin(width_phase * math.pi) * bend_strength

    return (styled[0], styled[1], styled[2])


def reversed_indices(indices: list[tuple[float, ...]]) -> list[tuple[int]]:
    flattened = [int(item[0]) for item in indices]
    if len(flattened) % 3 != 0:
        raise ValueError("Triangle index count is not divisible by 3.")

    reversed_flat: list[tuple[int]] = []
    for i in range(0, len(flattened), 3):
        a, b, c = flattened[i : i + 3]
        reversed_flat.extend([(a,), (c,), (b,)])
    return reversed_flat


def convert(
    input_path: Path,
    output_path: Path,
    *,
    depth_scale: float,
    outline_width: float,
    bend_strength: float,
) -> dict[str, Any]:
    gltf, binary = parse_glb(input_path)

    position_accessors: list[int] = []
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            position_index = primitive.get("attributes", {}).get("POSITION")
            if position_index is not None:
                position_accessors.append(position_index)

    if not position_accessors:
        raise ValueError("No POSITION accessors found.")

    original_positions: dict[int, list[tuple[float, ...]]] = {}
    mins = [float("inf"), float("inf"), float("inf")]
    maxs = [float("-inf"), float("-inf"), float("-inf")]

    for accessor_index in sorted(set(position_accessors)):
        values = read_accessor(gltf, binary, accessor_index)
        original_positions[accessor_index] = values
        for value in values:
            for axis in range(3):
                mins[axis] = min(mins[axis], float(value[axis]))
                maxs[axis] = max(maxs[axis], float(value[axis]))

    extents = [maxs[axis] - mins[axis] for axis in range(3)]
    center = [(mins[axis] + maxs[axis]) * 0.5 for axis in range(3)]
    depth_axis = min(range(3), key=lambda axis: extents[axis])
    height_axis = max(range(3), key=lambda axis: extents[axis])
    width_axis = max((axis for axis in range(3) if axis != height_axis), key=lambda axis: extents[axis])
    actual_bend = bend_strength * max(extents[depth_axis], 1e-6)
    actual_outline = outline_width * max(extents[width_axis], extents[height_axis], 1e-6)

    styled_positions: dict[int, list[tuple[float, float, float]]] = {}
    for accessor_index, values in original_positions.items():
        transformed = [
            transform_position(
                value,
                center=center,
                extents=extents,
                depth_axis=depth_axis,
                width_axis=width_axis,
                depth_scale=depth_scale,
                bend_strength=actual_bend,
            )
            for value in values
        ]
        styled_positions[accessor_index] = transformed
        write_accessor(gltf, binary, accessor_index, transformed)

    outline_material = style_materials(gltf)

    original_meshes = list(gltf.get("meshes", []))
    outline_primitive_count = 0
    color_accessor_count = 0

    for mesh in original_meshes:
        original_primitives = list(mesh.get("primitives", []))
        for primitive in original_primitives:
            attributes = primitive.get("attributes", {})
            position_index = attributes.get("POSITION")
            normal_index = attributes.get("NORMAL")
            indices_index = primitive.get("indices")
            if position_index is None or indices_index is None:
                continue

            positions = styled_positions[position_index]
            material_index = int(primitive.get("material", 0))

            if "COLOR_0" not in attributes:
                color_accessor = append_accessor(
                    gltf,
                    binary,
                    paper_vertex_colors(positions, material_index),
                    component_type=FLOAT,
                    type_name="VEC4",
                    target=ARRAY_BUFFER,
                )
                attributes["COLOR_0"] = color_accessor
                color_accessor_count += 1

            if normal_index is not None:
                normals = read_accessor(gltf, binary, normal_index)
            else:
                normals = []

            outline_positions: list[tuple[float, float, float]] = []
            for index, position in enumerate(positions):
                if index < len(normals):
                    nx, ny, nz = normalize(normals[index])
                else:
                    nx = position[0] - center[0]
                    ny = position[1] - center[1]
                    nz = position[2] - center[2]
                    nx, ny, nz = normalize((nx, ny, nz))

                outline_positions.append(
                    (
                        position[0] + nx * actual_outline,
                        position[1] + ny * actual_outline,
                        position[2] + nz * actual_outline,
                    )
                )

            outline_position_accessor = append_accessor(
                gltf,
                binary,
                outline_positions,
                component_type=FLOAT,
                type_name="VEC3",
                target=ARRAY_BUFFER,
            )

            outline_index_accessor = append_accessor(
                gltf,
                binary,
                reversed_indices(read_accessor(gltf, binary, indices_index)),
                component_type=UNSIGNED_INT,
                type_name="SCALAR",
                target=ELEMENT_ARRAY_BUFFER,
            )

            outline_attributes: dict[str, int] = {"POSITION": outline_position_accessor}
            for skinned_name in ("JOINTS_0", "WEIGHTS_0"):
                if skinned_name in attributes:
                    outline_attributes[skinned_name] = attributes[skinned_name]

            mesh.setdefault("primitives", []).append(
                {
                    "attributes": outline_attributes,
                    "indices": outline_index_accessor,
                    "material": outline_material,
                    "mode": primitive.get("mode", 4),
                    "extras": {"paperStyle": "inverted ink outline shell"},
                }
            )
            outline_primitive_count += 1

    gltf.setdefault("asset", {})["generator"] = "Codex direct GLB paper style converter"
    gltf["extras"] = {
        **gltf.get("extras", {}),
        "paperStyleConversion": {
            "source": str(input_path),
            "depthAxis": depth_axis,
            "depthScale": depth_scale,
            "outlineWidthWorld": actual_outline,
            "bendWorld": actual_bend,
            "outlinePrimitives": outline_primitive_count,
            "paperVertexColorAccessors": color_accessor_count,
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_glb(output_path, gltf, binary)

    return {
        "input": str(input_path),
        "output": str(output_path),
        "materials": len(gltf.get("materials", [])),
        "meshes": len(gltf.get("meshes", [])),
        "outline_primitives": outline_primitive_count,
        "vertex_color_accessors": color_accessor_count,
        "depth_axis": depth_axis,
        "depth_scale": depth_scale,
        "output_bytes": output_path.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input .glb file")
    parser.add_argument("output", type=Path, help="Output .glb file")
    parser.add_argument("--depth-scale", type=float, default=0.16, help="Scale along thinnest axis")
    parser.add_argument("--outline-width", type=float, default=0.010, help="Outline width as a fraction of model size")
    parser.add_argument("--bend-strength", type=float, default=0.026, help="Small paper bend as a fraction of original depth")
    args = parser.parse_args()

    summary = convert(
        args.input,
        args.output,
        depth_scale=args.depth_scale,
        outline_width=args.outline_width,
        bend_strength=args.bend_strength,
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
