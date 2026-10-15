#version 440

// Liquid Glass: Der Hintergrund wird am Rand wie durch eine dicke Linse gebrochen, die Kante fängt
// Licht, und unter dem Zeiger liegt ein weicher Lichtfleck.
// Neu übersetzen: qsb-qt6 --glsl "100 es,120,150" --hlsl 50 --msl 12 -o glass.frag.qsb glass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float bezel;
    float refraction;
    float tint;
    vec2 light;
    float glow;
};

layout(binding = 1) uniform sampler2D source;

float edge(vec2 p) {
    vec2 q = abs(p - size * 0.5) - size * 0.5 + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = edge(p);
    vec2 normal = normalize(vec2(edge(p + vec2(1.0, 0.0)) - edge(p - vec2(1.0, 0.0)),
                                 edge(p + vec2(0.0, 1.0)) - edge(p - vec2(0.0, 1.0))) + 1e-5);

    // Wölbung der Kante: innen flach, zum Rand hin immer steiler
    float rim = clamp(1.0 + d / bezel, 0.0, 1.0);
    float bend = 1.0 - sqrt(1.0 - rim * rim);
    vec2 shift = -normal * bend * refraction;

    // Farben brechen leicht unterschiedlich stark
    vec3 color = vec3(texture(source, (p + shift * 1.12) / size).r,
                      texture(source, (p + shift) / size).g,
                      texture(source, (p + shift * 0.88) / size).b);

    color = mix(color, vec3(0.06, 0.06, 0.07), tint);
    color += bend * 0.09;
    color += 0.035 * (1.0 - qt_TexCoord0.y);

    // Lichtkante: hell, wo die Kante zum Licht oben links zeigt, schwächer gegenüber
    float facing = dot(normal, normalize(vec2(-0.6, -0.8)));
    float line = smoothstep(-1.8, -0.4, d);
    color += line * (0.10 + 0.55 * pow(max(facing, 0.0), 2.0) + 0.28 * pow(max(-facing, 0.0), 3.0));

    float away = length(p - light);
    color += glow * 0.09 * exp(-away * away / 28800.0);

    fragColor = vec4(color, 1.0) * clamp(0.5 - d, 0.0, 1.0) * qt_Opacity;
}
