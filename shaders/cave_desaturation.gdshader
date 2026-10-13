shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
void fragment() {
	vec4 color = texture(screen_texture,SCREEN_UV);
	float gray = dot(color.rgb,vec3(0.299,0.587,0.114));
	COLOR = vec4(mix(color.rgb,vec3(gray),amount),1.0);
}
