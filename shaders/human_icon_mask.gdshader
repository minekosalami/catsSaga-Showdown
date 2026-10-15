shader_type canvas_item;
// The unchanged upstream SVGs have black backgrounds; use their white ink as a mask.
void fragment() {
 if (texture(TEXTURE,UV).r<0.5) discard;
}
