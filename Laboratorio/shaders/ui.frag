#version 330 core

in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

out vec4 FragColor;

void main() {
    vec4 texel = texture(uTexture, vTexCoord);
    FragColor = texel * uTint;
}
