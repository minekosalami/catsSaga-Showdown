shader_type canvas_item;
uniform float sweep = -1.0;
uniform vec4 accent : source_color = vec4(0.2,0.85,0.95,1.0);
varying float title_x;
void vertex() { title_x = VERTEX.x/500.0; }
void fragment() {
 vec4 glyph = texture(TEXTURE,UV)*COLOR;
 float glint = max(0.0,1.0-abs(title_x-sweep)/0.08);
 glyph.rgb = mix(glyph.rgb,mix(vec3(1.0),accent.rgb,0.18),glint*0.5);
 COLOR = glyph;
}
