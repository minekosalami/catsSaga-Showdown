shader_type canvas_item;
void fragment() {
	// Hide the existing roots/shadow below the flood surface; canopy stays opaque.
	vec4 source=texture(TEXTURE,UV)*COLOR;
	source.a*=step(UV.y,.62);
	COLOR=source;
}
