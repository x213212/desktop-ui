// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 aspectRatio;
    vec2 origin;
} state;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

float sparkle(vec2 cell)
{
    return fract(sin(dot(cell, vec2(41.37, 289.11))) * 17391.731);
}

void main()
{
    vec2 point = (qt_TexCoord0 - state.origin) * state.aspectRatio;
    float maximum = length(max(state.origin, vec2(1.0) - state.origin) * state.aspectRatio);
    float grain = sparkle(floor(qt_TexCoord0 * 96.0)) * 0.08;
    float boundary = smoothstep(0.0, 1.0, state.progress) * maximum;
    float reveal = 1.0 - smoothstep(boundary - 0.02, boundary + 0.03 + grain, length(point));
    vec4 color = mix(texture(fromImage, qt_TexCoord0),
                     texture(toImage, qt_TexCoord0), reveal);
    color.rgb += vec3(0.08, 0.10, 0.16) * (1.0 - abs(reveal * 2.0 - 1.0));
    fragColor = color * state.qt_Opacity;
}
