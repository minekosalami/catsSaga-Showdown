shader_type canvas_item;
uniform vec3 grass_color=vec3(.49,.63,.21);
uniform float source_green=.63;
varying vec4 tint;
varying vec2 world;
void vertex(){tint=COLOR;world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec4 art=texture(TEXTURE,UV);
 // Match only the artist's grass palette; dirt, foam and water remain unchanged.
 if(art.g>art.r*1.08 && art.b<art.g*.65)art.rgb=grass_color*(art.g/source_green);
 if(art.b>art.r+.15 && art.g>art.r+.15){
  vec2 p=floor(world/2.0)*2.0;
  art.rgb*=.98+.025*sin(p.x*.045+p.y*.035+TIME*.7);
 }
 COLOR=art*tint;
}
