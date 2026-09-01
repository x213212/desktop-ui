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
    float peak = 1.0 - abs(state.progress * 2.0 - 1.0);
    float cells = mix(320.0, 18.0, peak * peak);
    vec2 ratio = vec2(max(state.aspectX, 1.0), max(state.aspectY, 1.0));
    vec2 grid = vec2(cells) * ratio / max(ratio.x, ratio.y);
    vec2 samplePoint = (floor(qt_TexCoord0 * grid) + vec2(0.5)) / grid;
    float amount = smoothstep(0.36, 0.64, state.progress);
    fragColor = mix(texture(fromImage, samplePoint), texture(toImage, samplePoint), amount)
                * state.qt_Opacity;
}
