shader_type canvas_item;
render_mode unshaded;
uniform sampler2D rooms : filter_nearest, repeat_disable;
uniform sampler2D rock : source_color, filter_nearest, repeat_disable;
uniform vec2 map_size;
uniform vec2 top_left;
uniform vec2 axis_x;
uniform vec2 axis_y;
uniform float active_room = 1.0;
uniform vec2 player_position;
uniform vec4 window_rect;
uniform float clock;
bool belongs(vec2 point) {
	vec2 uv = point/map_size;
	vec2 ids = round(texture(rooms,uv).rg*255.0);
	bool inside = all(greaterThanEqual(uv,vec2(0.0))) && all(lessThan(uv,vec2(1.0)));
	bool visible = inside && (abs(ids.x-active_room)<0.5 || abs(ids.y-active_room)<0.5);
	if (inside && active_room == 6.0 && ids.x == 10.0 && point.x > window_rect.x && player_position.x < window_rect.x) {
		float crossing = player_position.y + (point.y-player_position.y)*(window_rect.x-player_position.x)/max(point.x-player_position.x,0.01);
		visible = crossing >= window_rect.y && crossing <= window_rect.y+window_rect.w;
	}
	return visible;
}
void fragment() {
	vec2 point = top_left+SCREEN_UV.x*axis_x+SCREEN_UV.y*axis_y;
	bool visible = belongs(point);
	// Conceal neighboring interiors with the actual stone atlas, rather than flat black boxes.
	vec3 stone = texture(rock,(vec2(1.0,3.0)+fract(point/32.0))/vec2(4.0,9.0)).rgb*vec3(.30,.26,.33);
	float haze = .01*(sin(point.x*.013+clock*.12)+sin(point.y*.017-clock*.09));
	stone += vec3(.016,.014,.019)+haze;
	float edge = 0.0;
	if (visible) {
		edge += belongs(point+vec2(42.0,0.0)) ? 0.0 : .14;
		edge += belongs(point-vec2(42.0,0.0)) ? 0.0 : .14;
		edge += belongs(point+vec2(0.0,42.0)) ? 0.0 : .14;
		edge += belongs(point-vec2(0.0,42.0)) ? 0.0 : .14;
		edge += smoothstep(.38,.72,length(SCREEN_UV-.5))*.20;
	}
	COLOR = vec4(stone,visible ? edge : 1.0);
}
