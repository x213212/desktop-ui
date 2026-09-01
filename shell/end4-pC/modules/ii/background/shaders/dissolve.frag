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

float cellNoise(vec2 point)
{
    vec2 cell = floor(point);
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void main()
{
    float coarse = cellNoise(qt_TexCoord0 * 54.0);
    float fine = cellNoise(qt_TexCoord0 * 137.0 + vec2(19.0));
    float threshold = coarse * 0.72 + fine * 0.28;
    float reveal = smoothstep(threshold - 0.025, threshold + 0.025, state.progress);
    float rim = 1.0 - smoothstep(0.0, 0.045, abs(threshold - state.progress));
    vec4 color = mix(texture(fromImage, qt_TexCoord0),
                     texture(toImage, qt_TexCoord0), reveal);
    color.rgb += vec3(0.10, 0.14, 0.22) * rim;
    fragColor = color * state.qt_Opacity;
}
