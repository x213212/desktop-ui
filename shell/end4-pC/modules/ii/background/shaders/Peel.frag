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
    float diagonal = (qt_TexCoord0.x + qt_TexCoord0.y) * 0.5;
    float edge = smoothstep(state.progress - 0.035, state.progress + 0.035, diagonal);
    vec2 oldUv = clamp(qt_TexCoord0 + vec2(state.progress * 0.025), vec2(0.0), vec2(1.0));
    vec4 oldColor = texture(fromImage, oldUv);
    vec4 newColor = texture(toImage, qt_TexCoord0);
    fragColor = mix(newColor, oldColor, edge) * state.qt_Opacity;
}
