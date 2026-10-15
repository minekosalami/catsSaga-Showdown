shader_type canvas_item;
uniform vec4 roof_color : source_color = vec4(.7,.5,.8,1);
uniform float roof_end = .7;
void fragment() {
	vec4 tex = texture(TEXTURE,UV)*COLOR;
	if(UV.y<roof_end && tex.r>.40 && tex.g>.25 && tex.r>tex.b*1.45 && tex.g>tex.b*1.1) {
		float lightness = dot(tex.rgb,vec3(.3,.6,.1));
		tex.rgb = mix(roof_color.rgb*.4,mix(roof_color.rgb,vec3(1),.37),smoothstep(.25,.95,lightness));
	}
	COLOR = tex;
}
