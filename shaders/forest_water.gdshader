shader_type canvas_item;
uniform float rain_strength = 0.0;
uniform float motion = 1.0;
varying vec2 world_point;
void vertex() {world_point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment() {
 vec4 source = COLOR;
 float water = step(.15,source.b-source.r);
 vec2 pixel = floor(world_point/2.0)*2.0;
 float clock = TIME*motion;
 float ripple = pow(.5+.5*sin(pixel.y*.09+sin(pixel.x*.025+clock*.24)*2.0+clock*(.6+rain_strength*.7)),18.0);
 source.rgb += vec3(.035,.05,.06)*ripple*water;
 source.rgb += vec3(.025,.035,.04)*rain_strength*sin(pixel.x*.23+pixel.y*.16+clock*2.0)*water;
 COLOR = source;
}
