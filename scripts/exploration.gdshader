shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
varying vec2 world_uv;
void vertex() {
    world_uv = (VERTEX.xz + vec2(96.0)) / 192.0;
    VERTEX.y = max(VERTEX.y, -0.12) + 0.06;
}
void fragment() {
    vec4 sight = texture(visibility_map, world_uv);
    float grain = fract(sin(dot(world_uv * 400.0, vec2(12.9898, 78.233))) * 43758.5453);
    ALBEDO = vec3(0.085, 0.135, 0.11) + grain * 0.025;
    ALPHA = mix(0.985, 0.30, sight.r) * (1.0 - sight.g);
}
