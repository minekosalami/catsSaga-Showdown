shader_type canvas_item;
void fragment() {
	vec4 base = COLOR;
	// Animate the existing green water subtly without replacing its atlas artwork.
	float ripple = sin(UV.x*128.0+TIME*.65)*sin(UV.y*128.0-TIME*.4);
	COLOR = vec4(base.rgb*(.97+.03*ripple),base.a);
}
