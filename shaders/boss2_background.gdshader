shader_type canvas_item;
// Repeat the unlettered upper half of the original grass; source image unchanged.
uniform float brightness = 0.77;
uniform float hit_glitch = 0.0;
uniform float clock = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 atmosphere : source_color = vec4(0.3, 0.7, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	uv.y = fract(uv.y * 2.0) * 0.5;
	uv.x += sin(floor(UV.y*75.0)*5.0+clock*90.0)*hit_glitch*0.007;
	float ripple = sin(uv.y * 35.0 + clock * 1.6) * cos(uv.x * 24.0 - clock);
	uv.x += ripple * intensity * 0.008;
	vec4 original = texture(TEXTURE, uv);
	vec3 color = original.rgb;
	color.r = texture(TEXTURE, uv + vec2(intensity * 0.004, 0.0)).r;
	color.b = texture(TEXTURE, uv - vec2(intensity * 0.004, 0.0)).b;
	float geometry = pow(abs(sin((UV.x + UV.y) * 32.0 + clock * 0.8)), 24.0);
	color = mix(color, atmosphere.rgb, intensity * 0.30);
	color += atmosphere.rgb * geometry * intensity * 0.18;
	float gray = dot(color,vec3(0.299,0.587,0.114));
	color = mix(vec3(gray),color,0.92) * brightness;
	float vignette = smoothstep(0.24,0.75,length(UV-vec2(0.5)));
	color *= 1.0-vignette*0.08;
	color = mix(color,vec3(0.65,0.12,0.20),hit_glitch*0.2);
	COLOR = vec4(color, original.a);
}
