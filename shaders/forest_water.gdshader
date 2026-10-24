shader_type canvas_item;
uniform float rain_strength = 0.0;
varying vec2 world_point;
void vertex() {world_point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment() {
 vec4 source = COLOR;
 float water = step(.15,source.b-source.r);
 float ripple = pow(.5+.5*sin(world_point.y*.09+sin(world_point.x*.025+TIME*.24)*2.0+TIME*(.6+rain_strength*.7)),18.0);
 source.rgb += vec3(.035,.05,.06)*ripple*water;
 source.rgb += vec3(.025,.035,.04)*rain_strength*sin(world_point.x*.23+world_point.y*.16+TIME*2.0)*water;
 COLOR = source;
}
