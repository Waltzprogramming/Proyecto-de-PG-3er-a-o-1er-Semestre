#version 330 core

in vec3 vWorldPosition;
in vec2 vUv;

uniform sampler2D uLavaMap;
uniform vec3 uBaseColor;
uniform vec3 uEmissiveColor;
uniform float uTime;

out vec4 FragColor;

float ridge(vec2 uv, float speed, float scale) {
    float a = sin((uv.x + uv.y * 0.55) * scale + uTime * speed);
    float b = sin((uv.x * 0.4 - uv.y) * scale * 1.7 - uTime * speed * 0.7);
    return pow(max((a + b) * 0.25 + 0.5, 0.0), 4.0);
}

void main() {
    vec2 uv1 = vUv + vec2(uTime * 0.10, -uTime * 0.06);
    vec2 uv2 = vUv * 1.7 + vec2(-uTime * 0.04, uTime * 0.11);
    vec3 tex = texture(uLavaMap, uv1).rgb * 0.72 + texture(uLavaMap, uv2).rgb * 0.28;
    float veins = ridge(vUv, 1.9, 4.0) + ridge(vUv.yx, 1.2, 7.5);
    vec3 color = mix(uBaseColor * tex, vec3(1.0, 0.80, 0.12), clamp(veins, 0.0, 1.0));
    color += uEmissiveColor * (0.42 + veins * 0.55);
    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));
    FragColor = vec4(color, 1.0);
}
