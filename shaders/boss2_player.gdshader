shader_type canvas_item;
uniform bool protected_flash = false;
uniform float hit_flash = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float edge = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = max(edge, texture(TEXTURE, UV + vec2(float(x),float(y)) * TEXTURE_PIXEL_SIZE * 2.0).a);
		}
	}
	vec3 ink = vec3(0.92,0.96,1.0);
	COLOR = vec4(mix(ink, source.rgb, source.a), max(source.a,edge * 0.65)) * COLOR;
	COLOR.rgb = mix(COLOR.rgb,vec3(1.0,0.3,0.45),hit_flash*0.6);
	if (protected_flash) COLOR.rgb = mix(COLOR.rgb, vec3(1.0), 0.7);
}
