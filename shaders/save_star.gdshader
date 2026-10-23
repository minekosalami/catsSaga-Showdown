shader_type canvas_item;
// The unchanged human-created Kenney icon supplies the complete silhouette.
// Threshold its source alpha for crisp black fill and a one-texel white edge.
varying float tint_alpha;
void vertex() {
	tint_alpha = COLOR.a;
}
void fragment() {
	float fill = step(0.5, texture(TEXTURE, UV).a);
	float edge = fill;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			edge = max(edge, step(0.5, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a));
		}
	}
	COLOR = vec4(vec3(1.0 - fill), edge * tint_alpha);
}
