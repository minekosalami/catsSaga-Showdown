shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain : filter_nearest, repeat_disable;
uniform sampler2D explored : filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(520.0, 372.0);
uniform vec2 center_world = vec2(0.0);
uniform vec2 canvas_size = vec2(150.0);
uniform float map_zoom = 2.5;
uniform bool circular = false;
uniform bool reveal_all = false;

void fragment() {
	if (circular && length((UV - vec2(0.5)) * 2.0) > 1.0) discard;
	vec2 point = center_world + (UV - vec2(0.5)) * canvas_size / map_zoom;
	vec2 sample_uv = point / atlas_size;
	bool inside = point.x >= 0.0 && point.y >= 0.0 && point.x < atlas_size.x && point.y < atlas_size.y;
	vec4 landscape = texture(terrain, sample_uv);
	float visited = reveal_all ? 1.0 : texture(explored, sample_uv).r;
	vec3 paper = vec3(0.035, 0.045, 0.040);
	vec3 fog = vec3(0.075, 0.090, 0.080);
	COLOR = vec4(inside && landscape.a > 0.0 ? mix(fog, landscape.rgb, visited) : paper, 1.0);
}
