shader_type canvas_item;
uniform vec4 shade : source_color = vec4(.08,.28,.32,1);
uniform vec4 leaf : source_color = vec4(.20,.76,.62,1);
uniform vec4 light_leaf : source_color = vec4(.70,.98,.70,1);
uniform float sway = 1.0;
void vertex() {
	VERTEX.x += sin(TIME*.72+MODEL_MATRIX[3].x*.017)*(1.0-UV.y)*sway;
}
void fragment() {
	vec4 tex = texture(TEXTURE,UV)*COLOR;
	if(tex.g>tex.r*1.06 && tex.g>tex.b*1.02) {
		float value = dot(tex.rgb,vec3(.2,.7,.1));
		tex.rgb = value<.52 ? mix(shade.rgb,leaf.rgb,smoothstep(.12,.52,value)) : mix(leaf.rgb,light_leaf.rgb,smoothstep(.52,.90,value));
	}
	COLOR = tex;
}
