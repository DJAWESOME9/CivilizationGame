shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform bool river_overlay = false;
// Feather the coarse visibility cells over three world units on both terrain
// and water. This changes presentation only; sightings still use simulation rules.
uniform float edge_softness : hint_range(0.5, 6.0) = 3.0;
varying vec2 world_uv;
void vertex() {
    world_uv = (VERTEX.xz + vec2(96.0)) / 192.0;
    VERTEX.y = max(VERTEX.y, -0.12) + 0.06;
}
vec2 visibility_at(vec2 sample_uv) {
    // The landscape extends beyond the saved exploration grid. Keep that apron
    // unknown instead of repeating an explored edge texel across the distance.
    if (any(lessThan(sample_uv, vec2(0.0))) || any(greaterThan(sample_uv, vec2(1.0)))) {
        return vec2(0.0);
    }
    return texture(visibility_map, sample_uv).rg;
}
vec2 softened_visibility(vec2 sample_uv) {
    vec2 step_uv = vec2(edge_softness / 192.0);
    vec2 sight = visibility_at(sample_uv) * 4.0;
    sight += visibility_at(sample_uv + vec2(step_uv.x, 0.0)) * 2.0;
    sight += visibility_at(sample_uv - vec2(step_uv.x, 0.0)) * 2.0;
    sight += visibility_at(sample_uv + vec2(0.0, step_uv.y)) * 2.0;
    sight += visibility_at(sample_uv - vec2(0.0, step_uv.y)) * 2.0;
    sight += visibility_at(sample_uv + step_uv);
    sight += visibility_at(sample_uv - step_uv);
    sight += visibility_at(sample_uv + vec2(step_uv.x, -step_uv.y));
    sight += visibility_at(sample_uv + vec2(-step_uv.x, step_uv.y));
    return smoothstep(vec2(0.02), vec2(0.98), sight / 16.0);
}
void fragment() {
    vec2 sight = softened_visibility(world_uv);
    float grain = fract(sin(dot(world_uv * 400.0, vec2(12.9898, 78.233))) * 43758.5453);
    ALBEDO = vec3(0.085, 0.135, 0.11) + grain * 0.025;
    if (river_overlay) {
        ALPHA = (1.0 - sight.r) * (1.0 - sight.g);
    } else {
        ALPHA = mix(0.985, 0.30, sight.r) * (1.0 - sight.g);
    }
}
