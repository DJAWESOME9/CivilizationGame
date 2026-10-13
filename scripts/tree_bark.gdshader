shader_type spatial;
uniform float sight_strength = 1.0;
varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    float grain = sin(local_position.x * 95.0 + sin(local_position.y * 7.0) + local_position.z * 81.0);
    ALBEDO = mix(vec3(0.16, 0.11, 0.065), vec3(0.30, 0.22, 0.13), grain * 0.5 + 0.5) * sight_strength;
    ROUGHNESS = 0.97;
}
