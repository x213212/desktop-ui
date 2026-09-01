// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspectX;
    float aspectY;
} state;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

void main()
{
    vec2 scale = vec2(max(state.aspectX, 1.0), max(state.aspectY, 1.0));
    float distanceFromCenter = length((qt_TexCoord0 - vec2(0.5)) * scale);
    float outerRadius = length(vec2(0.5) * scale);
    float edge = smoothstep(state.progress * outerRadius - 0.012,
                            state.progress * outerRadius + 0.012,
                            distanceFromCenter);
    vec2 pulled = vec2(0.5) + (qt_TexCoord0 - vec2(0.5)) * (0.92 + edge * 0.08);
    fragColor = mix(texture(toImage, pulled), texture(fromImage, qt_TexCoord0), edge)
                * state.qt_Opacity;
}
