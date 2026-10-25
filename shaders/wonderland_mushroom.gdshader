shader_type canvas_item;
uniform float motion = 1.0;
varying float phase;
void vertex(){
 phase=MODEL_MATRIX[3].x*.017+MODEL_MATRIX[3].y*.023;
 float top=clamp(-VERTEX.y/32.0,0.0,1.0);
 VERTEX.x+=sin(TIME*(.6+mod(phase,.4))+phase)*top*.4*motion;
 VERTEX.y+=sin(TIME*.8+phase)*top*.25*motion;
}
void fragment(){
 vec4 art=COLOR;
 float light=max(art.r,max(art.g,art.b));
 vec3 tint=mix(vec3(.43,.97,1.0),vec3(.94,.40,1.0),step(.5,fract(phase)));
 COLOR=vec4(mix(art.rgb,tint*light*1.6,.72),art.a);
}
