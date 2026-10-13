shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform int season = 0;
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world_pos.z * 1.9 + TIME * 0.75) * (season == 3 ? 0.004 : 0.025);
}
void fragment() {
    vec2 p = world_pos.xz;
    float long_wave = sin(p.y * 1.8 + p.x * 0.6 - TIME * 1.1);
    float cross_wave = sin(p.x * 8.0 + sin(p.y * 1.1 + TIME * 0.55) * 2.0);
    float fine_wave = sin((p.x + p.y) * 18.0 - TIME * 1.7);
    float wave = long_wave * 0.55 + cross_wave * 0.3 + fine_wave * 0.15;
    float glint = smoothstep(0.82, 0.98, sin(p.x * 13.0 + p.y * 4.0 - TIME * 1.25) * sin(p.y * 9.0 - TIME * 0.8));
    float fleck = hash21(floor(p * 5.0));
    vec3 deep = vec3(0.025, 0.13, 0.16);
    vec3 bright = vec3(0.10, 0.31, 0.32);
    vec3 color = mix(deep, bright, 0.48 + wave * 0.2 + fleck * 0.1);
    color = mix(color, vec3(0.55, 0.78, 0.73), glint * 0.32);
    if (season == 3) color = mix(color, vec3(0.58, 0.72, 0.76), 0.68);
    ALBEDO = color;
    ROUGHNESS = season == 3 ? 0.48 : 0.22;
    METALLIC = 0.08;
    SPECULAR = 0.72;
    NORMAL_MAP = vec3(0.5 + wave * 0.055, 0.5 + cross_wave * 0.035, 1.0);
}
