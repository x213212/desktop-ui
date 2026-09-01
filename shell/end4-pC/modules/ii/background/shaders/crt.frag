// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
} state;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

void main()
{
    float firstHalf = clamp(state.progress * 2.0, 0.0, 1.0);
    float secondHalf = clamp(state.progress * 2.0 - 1.0, 0.0, 1.0);
    float band = state.progress < 0.5
        ? mix(0.5, 0.006, firstHalf)
        : mix(0.006, 0.5, secondHalf);
    float distanceToLine = abs(qt_TexCoord0.y - 0.5);
    float inside = 1.0 - smoothstep(band - 0.003, band + 0.003, distanceToLine);
    vec2 compressedUv = vec2(qt_TexCoord0.x,
        0.5 + (qt_TexCoord0.y - 0.5) * 0.5 / max(band, 0.006));
    vec4 image = state.progress < 0.5
        ? texture(fromImage, compressedUv)
        : texture(toImage, compressedUv);
    float glow = exp(-distanceToLine / max(band, 0.006)) * 0.12;
    fragColor = vec4((image.rgb + vec3(glow)) * inside, image.a * inside)
                * state.qt_Opacity;
}
