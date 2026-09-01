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
    vec2 delta = (qt_TexCoord0 - state.origin) * state.aspectRatio;
    float distanceFromOrigin = length(delta);
    float maximum = length(max(state.origin, vec2(1.0) - state.origin) * state.aspectRatio);
    float front = state.progress * maximum;
    float pulse = sin((distanceFromOrigin - front) * 72.0)
                  * exp(-abs(distanceFromOrigin - front) * 34.0);
    vec2 direction = delta / max(distanceFromOrigin, 0.0001) / state.aspectRatio;
    vec2 samplePoint = clamp(qt_TexCoord0 + direction * pulse * 0.018,
                             vec2(0.0), vec2(1.0));
    float reveal = 1.0 - smoothstep(front - 0.01, front + 0.01, distanceFromOrigin);
    vec4 color = mix(texture(fromImage, samplePoint), texture(toImage, samplePoint), reveal);
    color.rgb += vec3(max(pulse, 0.0) * 0.08);
    fragColor = color * state.qt_Opacity;
}
