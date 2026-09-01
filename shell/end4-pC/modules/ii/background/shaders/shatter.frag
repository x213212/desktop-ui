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

vec2 shardVector(vec2 cell)
{
    vec2 value = vec2(dot(cell, vec2(37.2, 191.7)), dot(cell, vec2(117.9, 53.4)));
    return fract(sin(value) * 21431.321) - vec2(0.5);
}

void main()
{
    const float gridSize = 12.0;
    vec2 cell = floor(qt_TexCoord0 * gridSize);
    vec2 direction = shardVector(cell);
    float delay = fract(dot(direction, vec2(2.71, 5.93))) * 0.35;
    float travel = smoothstep(delay, 1.0, state.progress);
    vec2 oldSample = clamp(qt_TexCoord0 - direction * travel * 0.16,
                           vec2(0.0), vec2(1.0));
    float oldWeight = 1.0 - travel;
    vec4 oldColor = texture(fromImage, oldSample);
    vec4 newColor = texture(toImage, qt_TexCoord0);
    fragColor = mix(newColor, oldColor, oldWeight) * state.qt_Opacity;
}
