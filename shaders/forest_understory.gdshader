shader_type canvas_item;
uniform vec2 player_world = vec2(-10000.0);
varying vec2 world_point;
varying vec4 modulation;
void vertex() {world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;modulation=COLOR;}
void fragment() {
 vec2 cells=vec2(16.0,5.0);
 vec2 cell=floor(UV*cells);
 vec2 local=fract(UV*cells);
 float grass=step(1.5,cell.y)*step(cell.y,2.5);
 float contact=(1.0-smoothstep(16.0,75.0,distance(world_point,player_world)))*grass;
 float sway=(sin(TIME*1.15+world_point.x*.024)*.012+contact*.055*sign(world_point.x-player_world.x))*grass;
 local.x=clamp(local.x+sway*(1.0-smoothstep(.25,.88,local.y)),.008,.992);
 COLOR=texture(TEXTURE,(cell+local)/cells)*modulation;
}
