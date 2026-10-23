shader_type canvas_item;
uniform bool protected_flash = false;
uniform float hit_flash = 0.0;
uniform vec2 display_size = vec2(64.0);
varying vec4 modulation;
void vertex() {modulation=COLOR;}
void fragment() {
	vec2 grid=max(vec2(1.0),floor(display_size/2.0));
	vec2 uv=(floor(UV*grid)+.5)/grid;
	vec4 source = texture(TEXTURE, uv);
	float edge = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = max(edge, texture(TEXTURE, uv + vec2(float(x),float(y)) * TEXTURE_PIXEL_SIZE * 2.0).a);
		}
	}
	vec3 ink = vec3(0.92,0.96,1.0);
	COLOR = vec4(mix(ink, source.rgb, source.a), max(source.a,edge * 0.65)) * modulation;
	COLOR.rgb = mix(COLOR.rgb,vec3(1.0,0.3,0.45),hit_flash*0.6);
	if (protected_flash) COLOR.rgb = mix(COLOR.rgb, vec3(1.0), 0.7);
}
