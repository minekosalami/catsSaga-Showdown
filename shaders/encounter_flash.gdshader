shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	// Fragment COLOR already includes the sampled texture and vertex modulation.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
