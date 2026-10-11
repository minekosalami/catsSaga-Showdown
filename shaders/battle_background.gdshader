shader_type canvas_item;
uniform float clock = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 atmosphere : source_color = vec4(0.3, 0.7, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float ripple = sin(uv.y * 35.0 + clock * 1.6) * cos(uv.x * 24.0 - clock);
	uv.x += ripple * intensity * 0.008;
	vec4 original = texture(TEXTURE, uv);
	vec3 color = original.rgb;
	color.r = texture(TEXTURE, uv + vec2(intensity * 0.004, 0.0)).r;
	color.b = texture(TEXTURE, uv - vec2(intensity * 0.004, 0.0)).b;
	float geometry = pow(abs(sin((UV.x + UV.y) * 32.0 + clock * 0.8)), 24.0);
	color = mix(color, atmosphere.rgb, intensity * 0.30);
	color += atmosphere.rgb * geometry * intensity * 0.18;
	COLOR = vec4(color, original.a);
}
