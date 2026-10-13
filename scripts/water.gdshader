shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform int season = 0;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world_pos.z * 1.9 + TIME * 0.75) * (season == 3 ? 0.004 : 0.025);
}
void fragment() {
    float ripple = sin(world_pos.z * 6.0 + sin(world_pos.x * 1.7) * 1.3 + TIME * 1.4);
    float crosswave = sin(world_pos.x * 12.0 - TIME * 0.7 + sin(world_pos.z * 0.8) * 2.0);
    ALBEDO = mix(vec3(0.08, 0.20, 0.20), vec3(0.17, 0.32, 0.30), ripple * 0.035 + crosswave * 0.018 + 0.4);
    if (season == 3) ALBEDO = mix(ALBEDO, vec3(0.57, 0.70, 0.74), 0.72);
    ROUGHNESS = season == 3 ? 0.7 : 0.4;
    METALLIC = 0.15;
    NORMAL_MAP = vec3(0.5 + ripple * 0.008, 0.5 + crosswave * 0.006, 1.0);
}
