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

float columnOffset(float column)
{
    return fract(sin(column * 73.17) * 9182.53);
}

void main()
{
    float column = floor(qt_TexCoord0.x * 72.0);
    float lag = columnOffset(column) * 0.28;
    float fall = clamp((state.progress - lag) / 0.72, 0.0, 1.0);
    vec2 oldUv = qt_TexCoord0 - vec2(0.0, fall * 1.12);
    float oldVisible = step(0.0, oldUv.y) * step(oldUv.y, 1.0);
    vec4 oldColor = texture(fromImage, clamp(oldUv, vec2(0.0), vec2(1.0)));
    vec4 newColor = texture(toImage, qt_TexCoord0);
    fragColor = mix(newColor, oldColor, oldVisible) * state.qt_Opacity;
}
