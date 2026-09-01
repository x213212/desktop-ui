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

void main()
{
    vec2 scaled = (qt_TexCoord0 - state.origin) * state.aspectRatio;
    vec2 farthest = max(state.origin, vec2(1.0) - state.origin) * state.aspectRatio;
    float radius = length(farthest) * smoothstep(0.0, 1.0, state.progress);
    float feather = max(fwidth(length(scaled)) * 2.0, 0.001);
    float reveal = 1.0 - smoothstep(radius - feather, radius + feather, length(scaled));
    fragColor = mix(texture(fromImage, qt_TexCoord0),
                    texture(toImage, qt_TexCoord0), reveal) * state.qt_Opacity;
}
