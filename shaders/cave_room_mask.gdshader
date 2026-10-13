shader_type canvas_item;
render_mode unshaded;
uniform sampler2D rooms : filter_nearest, repeat_disable;
uniform vec2 map_size;
uniform vec2 top_left;
uniform vec2 axis_x;
uniform vec2 axis_y;
uniform float active_room = 1.0;
uniform vec2 player_position;
uniform vec4 window_rect;
void fragment() {
	vec2 point = top_left + SCREEN_UV.x * axis_x + SCREEN_UV.y * axis_y;
	vec2 uv = point / map_size;
	vec2 ids = round(texture(rooms,uv).rg * 255.0);
	bool inside = all(greaterThanEqual(uv,vec2(0.0))) && all(lessThan(uv,vec2(1.0)));
	bool visible = inside && (abs(ids.x-active_room)<0.5 || abs(ids.y-active_room)<0.5);
	if (inside && active_room == 6.0 && ids.x == 10.0 && point.x > window_rect.x && player_position.x < window_rect.x) {
		float crossing = player_position.y + (point.y-player_position.y) * (window_rect.x-player_position.x) / max(point.x-player_position.x,0.01);
		visible = crossing >= window_rect.y && crossing <= window_rect.y+window_rect.w;
	}
	COLOR = vec4(0.015,0.013,0.02,visible ? 0.0 : 1.0);
}
