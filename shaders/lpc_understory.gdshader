shader_type canvas_item;
uniform vec2 player_world = vec2(-10000.0);
varying vec2 world_point;
varying vec4 modulation;
void vertex() {
	world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	modulation=COLOR;
}
void fragment() {
	// UV displacement stays within each original 32px plant, regardless of sheet size.
	vec2 cells=1.0/(TEXTURE_PIXEL_SIZE*32.0);
	vec2 cell=floor(UV*cells);
	vec2 local=fract(UV*cells);
	float contact=1.0-smoothstep(16.0,60.0,distance(world_point,player_world));
	float sway=(sin(TIME*.8+world_point.x*.03)*.006+contact*.018)*(1.0-local.y);
	local.x=clamp(local.x+sway,.001,.999);
	COLOR=texture(TEXTURE,(cell+local)/cells)*modulation;
}
