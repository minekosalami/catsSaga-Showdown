shader_type canvas_item;
uniform float coverage : hint_range(0.0,1.0) = 0.0;
uniform bool reverse=false;
uniform vec4 paper : source_color = vec4(.93,.88,.72,1.0);
void fragment(){
 // A curved page edge, made entirely from a transition shader (no artwork).
 float edge=coverage*1.28-.14 + sin(UV.y*3.14159)*.08;
 float across=reverse?1.0-UV.x:UV.x;
 float alpha=smoothstep(across-.004,across+.004,edge);
 float fold=clamp((edge-across)/.065,0.0,1.0);
 vec3 color=paper.rgb*mix(.82,1.0,fold);
 COLOR=vec4(color,alpha);
}
