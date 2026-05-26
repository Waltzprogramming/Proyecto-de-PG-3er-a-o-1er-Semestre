#version 330 core

layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUv;
layout (location = 3) in vec4 aColor;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;
uniform float uTime;

out vec3 vWorldPosition;
out vec2 vUv;

void main() {
    vec3 animated = aPosition;
    animated.y += sin(aPosition.x * 10.0 + uTime * 1.7) * 0.018;
    animated.y += sin(aPosition.z * 12.0 + uTime * 2.3) * 0.014;
    vec4 world = uModel * vec4(animated, 1.0);
    vWorldPosition = world.xyz;
    vUv = aUv * 12.0;
    gl_Position = uProjection * uView * world;
}
