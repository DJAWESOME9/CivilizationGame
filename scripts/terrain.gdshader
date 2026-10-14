shader_type spatial;
render_mode cull_disabled;
uniform sampler2D meadow : source_color, repeat_enable;
uniform int season = 0;
uniform int next_season = 1;
uniform float season_blend = 0.0;
vec3 seasonal_ground(int season, vec3 grass, vec2 uv, float normal_y) {
    vec3 tint = season == 0 ? vec3(0.43, 0.58, 0.37) : season == 1 ? vec3(0.53, 0.57, 0.36) : vec3(0.65, 0.48, 0.28);
    vec3 ground = grass * tint;
    if (season == 3) {
        float patch = texture(meadow, uv * 0.27).r;
        float cover = smoothstep(0.12, 0.58, patch) * smoothstep(0.35, 0.8, normal_y);
        ground = mix(grass * vec3(0.40, 0.43, 0.38), vec3(0.80, 0.85, 0.85) * (0.88 + grass.r * 0.12), cover * 0.96);
    }
    return ground;
}
void fragment() {
    vec3 grass = texture(meadow, UV * 0.9).rgb;
    ALBEDO = mix(seasonal_ground(season, grass, UV, NORMAL.y), seasonal_ground(next_season, grass, UV, NORMAL.y), season_blend);
    ROUGHNESS = 0.94;
}
