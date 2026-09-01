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
    float amount = smoothstep(0.0, 1.0, state.progress);
    fragColor = mix(texture(fromImage, qt_TexCoord0),
                    texture(toImage, qt_TexCoord0), amount) * state.qt_Opacity;
}
