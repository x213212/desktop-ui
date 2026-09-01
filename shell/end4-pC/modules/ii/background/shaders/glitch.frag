// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 desktop-ui contributors

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float time;
} state;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

float randomValue(vec2 value)
{
    return fract(sin(dot(value, vec2(91.7, 263.4))) * 15731.743);
}

void main()
{
    float envelope = sin(clamp(state.progress, 0.0, 1.0) * 3.14159265);
    float row = floor(qt_TexCoord0.y * 30.0);
    float shift = (randomValue(vec2(row, floor(state.time * 24.0))) - 0.5)
                  * envelope * 0.055;
    vec2 shifted = clamp(qt_TexCoord0 + vec2(shift, 0.0), vec2(0.0), vec2(1.0));
    vec4 base = mix(texture(fromImage, shifted), texture(toImage, shifted), state.progress);
    float split = envelope * 0.009;
    base.r = mix(texture(fromImage, shifted + vec2(split, 0.0)).r,
                 texture(toImage, shifted + vec2(split, 0.0)).r, state.progress);
    base.b = mix(texture(fromImage, shifted - vec2(split, 0.0)).b,
                 texture(toImage, shifted - vec2(split, 0.0)).b, state.progress);
    fragColor = base * state.qt_Opacity;
}
