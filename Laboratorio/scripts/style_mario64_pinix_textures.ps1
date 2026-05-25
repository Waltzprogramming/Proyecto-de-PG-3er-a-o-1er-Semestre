param(
    [string]$ModelDir = "assets\characters\mario64_pinix_style\model"
)

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

function Resolve-ModelPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path (Get-Location) $Path
}

function New-Color([string]$Hex, [int]$Alpha = 255) {
    $clean = $Hex.TrimStart("#")
    return [System.Drawing.Color]::FromArgb(
        $Alpha,
        [Convert]::ToInt32($clean.Substring(0, 2), 16),
        [Convert]::ToInt32($clean.Substring(2, 2), 16),
        [Convert]::ToInt32($clean.Substring(4, 2), 16)
    )
}

function Mix-Color([System.Drawing.Color]$A, [System.Drawing.Color]$B, [double]$T) {
    $t = [Math]::Max(0.0, [Math]::Min(1.0, $T))
    return [System.Drawing.Color]::FromArgb(
        [int]($A.A + (($B.A - $A.A) * $t)),
        [int]($A.R + (($B.R - $A.R) * $t)),
        [int]($A.G + (($B.G - $A.G) * $t)),
        [int]($A.B + (($B.B - $A.B) * $t))
    )
}

function Save-PaperFill(
    [string]$Path,
    [int]$Width,
    [int]$Height,
    [System.Drawing.Color]$Base,
    [System.Drawing.Color]$Highlight,
    [System.Drawing.Color]$Shadow
) {
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $grain = ((($x * 19 + $y * 31 + ($x * $y * 7)) % 17) - 8) / 80.0
                $diagonal = (($x + $y) / [Math]::Max(1, $Width + $Height)) * 0.14
                $color = Mix-Color $Base $Highlight ([Math]::Max(0, $diagonal + $grain))
                if ((($x * 5 + $y * 11) % 23) -eq 0) {
                    $color = Mix-Color $color $Shadow 0.12
                }
                $bmp.SetPixel($x, $y, $color)
            }
        }
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bmp.Dispose()
    }
}

function New-Canvas([int]$Width, [int]$Height, [System.Drawing.Color]$Base) {
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($Base)
    return @{ Bitmap = $bmp; Graphics = $g }
}

function Save-And-Close($Canvas, [string]$Path) {
    $Canvas.Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Canvas.Graphics.Dispose()
    $Canvas.Bitmap.Dispose()
}

function Draw-OutlinedText(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [System.Drawing.Font]$Font,
    [System.Drawing.RectangleF]$Rect,
    [System.Drawing.Brush]$Fill,
    [System.Drawing.Pen]$Stroke
) {
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $path.AddString($Text, $Font.FontFamily, [int]$Font.Style, $Font.Size, $Rect, $format)
        $Graphics.DrawPath($Stroke, $path)
        $Graphics.FillPath($Fill, $path)
    }
    finally {
        $path.Dispose()
        $format.Dispose()
    }
}

function Save-Material0([string]$Path) {
    $skin = New-Color "#f3b36d"
    $canvas = New-Canvas 64 64 $skin
    $g = $canvas.Graphics
    $hair = New-Object System.Drawing.SolidBrush (New-Color "#22180f")
    $line = New-Object System.Drawing.Pen (New-Color "#080706"), 3
    try {
        $points = [System.Drawing.Point[]]@(
            (New-Object System.Drawing.Point 9, 48),
            (New-Object System.Drawing.Point 22, 34),
            (New-Object System.Drawing.Point 36, 15),
            (New-Object System.Drawing.Point 58, 12),
            (New-Object System.Drawing.Point 51, 38),
            (New-Object System.Drawing.Point 30, 50)
        )
        $g.FillClosedCurve($hair, $points)
        $g.DrawClosedCurve($line, $points)
        Save-And-Close $canvas $Path
    }
    finally {
        $hair.Dispose()
        $line.Dispose()
    }
}

function Save-Eyes([string]$Path) {
    $skin = New-Color "#f2b16d"
    $canvas = New-Canvas 64 64 $skin
    $g = $canvas.Graphics
    $black = New-Object System.Drawing.SolidBrush (New-Color "#050505")
    $brow = New-Object System.Drawing.Pen (New-Color "#17110c"), 5
    try {
        $g.DrawArc($brow, 12, 10, 15, 13, 205, 120)
        $g.DrawArc($brow, 38, 10, 15, 13, 215, 120)
        $g.FillEllipse($black, 17, 26, 10, 24)
        $g.FillEllipse($black, 41, 26, 10, 24)
        Save-And-Close $canvas $Path
    }
    finally {
        $black.Dispose()
        $brow.Dispose()
    }
}

function Save-FacialHair([string]$Path) {
    $skin = New-Color "#f2b16d"
    $canvas = New-Canvas 64 64 $skin
    $g = $canvas.Graphics
    $hair = New-Object System.Drawing.SolidBrush (New-Color "#060504")
    try {
        $points = [System.Drawing.Point[]]@(
            (New-Object System.Drawing.Point 9, 51),
            (New-Object System.Drawing.Point 16, 35),
            (New-Object System.Drawing.Point 34, 32),
            (New-Object System.Drawing.Point 55, 14),
            (New-Object System.Drawing.Point 52, 37),
            (New-Object System.Drawing.Point 35, 51)
        )
        $g.FillClosedCurve($hair, $points)
        Save-And-Close $canvas $Path
    }
    finally {
        $hair.Dispose()
    }
}

function Save-CapBadge([string]$Path) {
    $navy = New-Color "#172747"
    $canvas = New-Canvas 64 64 $navy
    $g = $canvas.Graphics
    $fabricPen = New-Object System.Drawing.Pen (New-Color "#26395f"), 1
    $blackPen = New-Object System.Drawing.Pen (New-Color "#070707"), 4
    $rimPen = New-Object System.Drawing.Pen (New-Color "#d8d8d4"), 5
    $whiteBrush = New-Object System.Drawing.SolidBrush (New-Color "#f0f0e8")
    $goldBrush = New-Object System.Drawing.SolidBrush (New-Color "#f0a51c")
    $pStroke = New-Object System.Drawing.Pen (New-Color "#4a2600"), 4
    $font = New-Object System.Drawing.Font "Arial Black", 31, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    try {
        for ($i = 0; $i -lt 64; $i += 6) {
            $g.DrawLine($fabricPen, 0, $i, 64, $i + 12)
        }
        $g.FillEllipse($whiteBrush, 16, 8, 34, 38)
        $g.DrawEllipse($blackPen, 16, 8, 34, 38)
        $g.DrawEllipse($rimPen, 20, 12, 26, 30)
        Draw-OutlinedText $g "P" $font (New-Object System.Drawing.RectangleF 17, 11, 34, 34) $goldBrush $pStroke
        Save-And-Close $canvas $Path
    }
    finally {
        $fabricPen.Dispose()
        $blackPen.Dispose()
        $rimPen.Dispose()
        $whiteBrush.Dispose()
        $goldBrush.Dispose()
        $pStroke.Dispose()
        $font.Dispose()
    }
}

function Save-Button([string]$Path) {
    $navy = New-Color "#172747"
    $canvas = New-Canvas 32 32 $navy
    $g = $canvas.Graphics
    $outer = New-Object System.Drawing.SolidBrush (New-Color "#050505")
    $metal = New-Object System.Drawing.SolidBrush (New-Color "#d7d9d6")
    $shade = New-Object System.Drawing.SolidBrush (New-Color "#9ca3a3")
    try {
        $g.FillEllipse($outer, 5, 4, 22, 23)
        $g.FillEllipse($metal, 8, 6, 17, 18)
        $g.FillEllipse($shade, 11, 9, 10, 11)
        Save-And-Close $canvas $Path
    }
    finally {
        $outer.Dispose()
        $metal.Dispose()
        $shade.Dispose()
    }
}

function Save-ShirtDecal([string]$Path) {
    $canvas = New-Canvas 256 96 ([System.Drawing.Color]::Transparent)
    $g = $canvas.Graphics
    $panel = New-Object System.Drawing.SolidBrush (New-Color "#b9bebc")
    $shadow = New-Object System.Drawing.Pen (New-Color "#050505"), 8
    $textBrush = New-Object System.Drawing.SolidBrush (New-Color "#232323")
    $font = New-Object System.Drawing.Font "Arial Black", 40, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    try {
        $g.FillRectangle($panel, 7, 8, 242, 80)
        $g.DrawRectangle($shadow, 7, 8, 242, 80)
        Draw-OutlinedText $g "PINIX" $font (New-Object System.Drawing.RectangleF 13, 16, 230, 62) $textBrush (New-Object System.Drawing.Pen (New-Color "#d9dddd"), 2)
        Save-And-Close $canvas $Path
    }
    finally {
        $panel.Dispose()
        $shadow.Dispose()
        $textBrush.Dispose()
        $font.Dispose()
    }
}

function Copy-TextureSet([string]$FromDir, [string]$ToDir) {
    if (!(Test-Path $ToDir)) {
        return
    }
    Get-ChildItem -Path $FromDir -Filter "*.png" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $ToDir $_.Name) -Force
    }
}

function Add-Bytes([System.IO.FileStream]$Stream, [byte[]]$Bytes) {
    $Stream.Write($Bytes, 0, $Bytes.Length)
}

function Add-FloatArray([System.IO.FileStream]$Stream, [single[]]$Values) {
    foreach ($value in $Values) {
        Add-Bytes $Stream ([BitConverter]::GetBytes($value))
    }
}

function Add-UIntArray([System.IO.FileStream]$Stream, [uint32[]]$Values) {
    foreach ($value in $Values) {
        Add-Bytes $Stream ([BitConverter]::GetBytes($value))
    }
}

function Align-Stream4([System.IO.FileStream]$Stream) {
    while (($Stream.Length % 4) -ne 0) {
        $Stream.WriteByte(0)
    }
}

function Set-ObjectProperty($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Has-ObjectProperty($Object, [string]$Name) {
    return $Object.PSObject.Properties.Name -contains $Name
}

function Append-Accessor($Gltf, [System.IO.FileStream]$Stream, [array]$Values, [string]$Type, [int]$ComponentType, [int]$ComponentCount, $Target) {
    Align-Stream4 $Stream
    $offset = [int64]$Stream.Length
    if ($ComponentType -eq 5126) {
        Add-FloatArray $Stream ([single[]]$Values)
        $componentBytes = 4
    }
    elseif ($ComponentType -eq 5125) {
        Add-UIntArray $Stream ([uint32[]]$Values)
        $componentBytes = 4
    }
    else {
        throw "Unsupported component type $ComponentType"
    }
    $byteLength = [int]($Stream.Length - $offset)

    $view = [ordered]@{
        buffer = 0
        byteOffset = [int]$offset
        byteLength = $byteLength
    }
    if ($null -ne $Target) {
        $view.target = [int]$Target
    }
    $Gltf.bufferViews += $view
    $viewIndex = $Gltf.bufferViews.Count - 1

    $count = [int]($Values.Count / $ComponentCount)
    $accessor = [ordered]@{
        bufferView = $viewIndex
        componentType = $ComponentType
        count = $count
        type = $Type
    }

    if ($ComponentType -eq 5126) {
        $mins = @()
        $maxs = @()
        for ($c = 0; $c -lt $ComponentCount; $c++) {
            $channel = @()
            for ($i = $c; $i -lt $Values.Count; $i += $ComponentCount) {
                $channel += [double]$Values[$i]
            }
            $mins += (($channel | Measure-Object -Minimum).Minimum)
            $maxs += (($channel | Measure-Object -Maximum).Maximum)
        }
        $accessor.min = $mins
        $accessor.max = $maxs
    }

    $Gltf.accessors += $accessor
    return $Gltf.accessors.Count - 1
}

function Write-GltfJson($Gltf, [string]$Path) {
    $json = $Gltf | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Set-PinixDecalParent($Gltf) {
    $decalNodeIndex = -1
    for ($i = 0; $i -lt $Gltf.nodes.Count; $i++) {
        if ($Gltf.nodes[$i].name -eq "PINIX_shirt_decal") {
            $decalNodeIndex = $i
            break
        }
    }
    if ($decalNodeIndex -lt 0) {
        return
    }

    $parentNodeIndex = -1
    for ($i = 0; $i -lt $Gltf.nodes.Count; $i++) {
        if ($Gltf.nodes[$i].name -eq "Prototype Mario (Super Mario 64).obj.cleaner.materialmerger.gles_1") {
            $parentNodeIndex = $i
            break
        }
    }
    if ($parentNodeIndex -lt 0) {
        for ($i = 0; $i -lt $Gltf.nodes.Count; $i++) {
            if ((Has-ObjectProperty $Gltf.nodes[$i] "children") -and @($Gltf.nodes[$i].children).Count -gt 8) {
                $parentNodeIndex = $i
                break
            }
        }
    }
    if ($parentNodeIndex -lt 0) {
        throw "Could not find the Mario model node to attach the PINIX decal."
    }

    foreach ($scene in $Gltf.scenes) {
        if (Has-ObjectProperty $scene "nodes") {
            $scene.nodes = @($scene.nodes | Where-Object { [int]$_ -ne $decalNodeIndex })
        }
    }

    $parent = $Gltf.nodes[$parentNodeIndex]
    if (!(Has-ObjectProperty $parent "children")) {
        Set-ObjectProperty $parent "children" @()
    }
    if (@($parent.children | Where-Object { [int]$_ -eq $decalNodeIndex }).Count -eq 0) {
        $parent.children = @($parent.children) + $decalNodeIndex
    }
}

function Add-PinixDecal([string]$ModelRoot) {
    $gltfPath = Join-Path $ModelRoot "scene.gltf"
    $binPath = Join-Path $ModelRoot "scene.bin"
    $gltf = Get-Content -Raw -LiteralPath $gltfPath | ConvertFrom-Json

    if (@($gltf.materials | Where-Object { $_.name -eq "PINIX_shirt_decal" }).Count -gt 0) {
        Set-PinixDecalParent $gltf
        Write-GltfJson $gltf $gltfPath
        return
    }

    if (!(Has-ObjectProperty $gltf "extensionsUsed")) {
        Set-ObjectProperty $gltf "extensionsUsed" @()
    }
    if ($gltf.extensionsUsed -notcontains "KHR_materials_unlit") {
        $gltf.extensionsUsed += "KHR_materials_unlit"
    }

    foreach ($material in $gltf.materials) {
        $material.doubleSided = $true
        if (!(Has-ObjectProperty $material "pbrMetallicRoughness")) {
            Set-ObjectProperty $material "pbrMetallicRoughness" ([ordered]@{})
        }
        Set-ObjectProperty $material.pbrMetallicRoughness "metallicFactor" 0.0
        Set-ObjectProperty $material.pbrMetallicRoughness "roughnessFactor" 1.0
        if (!(Has-ObjectProperty $material "extensions")) {
            Set-ObjectProperty $material "extensions" ([ordered]@{})
        }
        Set-ObjectProperty $material.extensions "KHR_materials_unlit" ([ordered]@{})
    }

    foreach ($name in @("Material_11", "Material_15")) {
        $mat = $gltf.materials | Where-Object { $_.name -eq $name } | Select-Object -First 1
        if ($null -ne $mat) {
            Set-ObjectProperty $mat.pbrMetallicRoughness "baseColorFactor" @(0.88, 0.88, 0.84, 1.0)
        }
    }

    $gltf.samplers += [ordered]@{
        magFilter = 9729
        minFilter = 9729
        wrapS = 33071
        wrapT = 33071
    }
    $samplerIndex = $gltf.samplers.Count - 1

    $gltf.images += [ordered]@{ uri = "textures/Pinix_shirt_decal.png" }
    $imageIndex = $gltf.images.Count - 1

    $gltf.textures += [ordered]@{
        sampler = $samplerIndex
        source = $imageIndex
    }
    $textureIndex = $gltf.textures.Count - 1

    $gltf.materials += [ordered]@{
        name = "PINIX_shirt_decal"
        doubleSided = $true
        alphaMode = "BLEND"
        pbrMetallicRoughness = [ordered]@{
            baseColorTexture = [ordered]@{ index = $textureIndex }
            baseColorFactor = @(1.0, 1.0, 1.0, 1.0)
            metallicFactor = 0.0
            roughnessFactor = 1.0
        }
        extensions = [ordered]@{ KHR_materials_unlit = [ordered]@{} }
    }
    $materialIndex = $gltf.materials.Count - 1

    $positions = [single[]]@(
        -0.54, 12.34, -1.78,   0.54, 12.34, -1.78,   0.54, 12.34, -1.36,  -0.54, 12.34, -1.36,
        -0.54, 14.82, -1.78,  -0.54, 14.82, -1.36,   0.54, 14.82, -1.36,   0.54, 14.82, -1.78
    )
    $normals = [single[]]@(
         0.0, -1.0, 0.0,   0.0, -1.0, 0.0,   0.0, -1.0, 0.0,   0.0, -1.0, 0.0,
         0.0,  1.0, 0.0,   0.0,  1.0, 0.0,   0.0,  1.0, 0.0,   0.0,  1.0, 0.0
    )
    $uvs = [single[]]@(
        0.0, 1.0,  1.0, 1.0,  1.0, 0.0,  0.0, 0.0,
        0.0, 1.0,  0.0, 0.0,  1.0, 0.0,  1.0, 1.0
    )
    $indices = [uint32[]]@(0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7)

    $stream = [System.IO.File]::Open($binPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
    try {
        $posAccessor = Append-Accessor $gltf $stream $positions "VEC3" 5126 3 34962
        $normalAccessor = Append-Accessor $gltf $stream $normals "VEC3" 5126 3 34962
        $uvAccessor = Append-Accessor $gltf $stream $uvs "VEC2" 5126 2 34962
        $indexAccessor = Append-Accessor $gltf $stream $indices "SCALAR" 5125 1 34963
        Align-Stream4 $stream
    }
    finally {
        $stream.Dispose()
    }

    $gltf.buffers[0].byteLength = (Get-Item -LiteralPath $binPath).Length

    $gltf.meshes += [ordered]@{
        name = "PINIX_shirt_decal_mesh"
        primitives = @(
            [ordered]@{
                attributes = [ordered]@{
                    POSITION = $posAccessor
                    NORMAL = $normalAccessor
                    TEXCOORD_0 = $uvAccessor
                }
                indices = $indexAccessor
                material = $materialIndex
                mode = 4
            }
        )
    }
    $meshIndex = $gltf.meshes.Count - 1

    $gltf.nodes += [ordered]@{
        mesh = $meshIndex
        name = "PINIX_shirt_decal"
    }
    $nodeIndex = $gltf.nodes.Count - 1

    Set-PinixDecalParent $gltf

    if (!(Has-ObjectProperty $gltf "extras")) {
        Set-ObjectProperty $gltf "extras" ([ordered]@{})
    }
    Set-ObjectProperty $gltf.extras "pinixTextureStyle" ([ordered]@{
        palette = "dark navy, warm skin, white gloves, gray shoes, gold P badge"
        addedDecal = "PINIX_shirt_decal"
    })

    Write-GltfJson $gltf $gltfPath
}

$root = Resolve-ModelPath $ModelDir
$textureDir = Join-Path $root "textures"
if (!(Test-Path $textureDir)) {
    throw "Texture directory not found: $textureDir"
}

Save-Material0 (Join-Path $textureDir "Material_0_baseColor.png")
Save-Eyes (Join-Path $textureDir "Material_1_baseColor.png")
Save-FacialHair (Join-Path $textureDir "Material_2_baseColor.png")
Save-PaperFill (Join-Path $textureDir "Material_10_baseColor.png") 8 8 (New-Color "#182947") (New-Color "#2d416a") (New-Color "#07101f")
Save-PaperFill (Join-Path $textureDir "Material_12_baseColor.png") 8 8 (New-Color "#172747") (New-Color "#2a3f66") (New-Color "#060b14")
Save-PaperFill (Join-Path $textureDir "Material_3_baseColor.png") 8 8 (New-Color "#21150b") (New-Color "#3a2a18") (New-Color "#050403")
Save-CapBadge (Join-Path $textureDir "Material_4_baseColor.png")
Save-PaperFill (Join-Path $textureDir "Material_5_baseColor.png") 8 8 (New-Color "#202c45") (New-Color "#516173") (New-Color "#070a10")
Save-Button (Join-Path $textureDir "Material_18_baseColor.png")
Save-ShirtDecal (Join-Path $textureDir "Pinix_shirt_decal.png")

Add-PinixDecal $root
Copy-TextureSet $textureDir (Join-Path (Split-Path $root -Parent) "textures")

Write-Host "Styled Mario 64 PINIX textures written to $root"
