shader_type spatial;
render_mode diffuse_burley;

uniform int season = 0;
uniform int next_season = 1;
uniform float season_blend = 0.0;
uniform float sight_strength = 1.0;
uniform float variation = 0.5;
varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec3 spring = mix(vec3(0.24, 0.38, 0.10), vec3(0.40, 0.52, 0.17), variation);
    vec3 summer = mix(vec3(0.16, 0.29, 0.07), vec3(0.30, 0.39, 0.10), variation);
    vec3 autumn = mix(vec3(0.45, 0.20, 0.055), vec3(0.66, 0.43, 0.12), variation);
    vec3 winter = mix(vec3(0.39, 0.45, 0.36), vec3(0.61, 0.65, 0.57), variation);
    vec3 color = season == 0 ? spring : (season == 1 ? summer : (season == 2 ? autumn : winter));
    vec3 next_color = next_season == 0 ? spring : (next_season == 1 ? summer : (next_season == 2 ? autumn : winter));
    color = mix(color, next_color, season_blend);
    // Fine mottling gives the solid canopy leaf-sized detail, without alpha cards.
    vec3 cell = floor(local_position * 19.0);
    float fleck = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    ALBEDO = color * mix(0.78, 1.18, fleck) * sight_strength;
    ROUGHNESS = 0.92;
}
