shader_type canvas_item;
uniform float clock = 0.0;
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5,0.0)) * vec2(2.4,1.0);
	float contour = sin(length(p + vec2(sin(clock*.13)*.04,0.0))*43.0-clock*.4);
	float veins = pow(max(0.0,contour),14.0);
	float top = 1.0-smoothstep(.32,.95,UV.y);
	COLOR = vec4(vec3(.48,.14,.16),veins*top*strength*.14);
}
