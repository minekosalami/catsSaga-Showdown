shader_type canvas_item;
uniform vec3 grass_color=vec3(.49,.63,.21);
uniform float source_green=.63;
varying vec4 tint;
varying vec2 world;
void vertex(){tint=COLOR;world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec4 art=texture(TEXTURE,UV);
 // Match only the artist's grass palette; dirt, foam and water remain unchanged.
 // The water atlas has an olive grass-shadow swatch whose red exceeds green.
 // Include that exact authored swatch instead of leaving a yellow shoreline stripe.
 bool olive_bank=distance(art.rgb,vec3(168.,161.,41.)/255.)<.012;
 if(olive_bank || (art.g>art.r*1.08 && art.b<art.g*.65))art.rgb=grass_color*(art.g/source_green);
 if(art.b>art.r+.15 && art.g>art.r+.15){
  vec2 p=floor(world/2.0)*2.0;
  float ripple=sin(p.x*.09+p.y*.02+TIME*.7)*sin(p.y*.13-TIME*.6);
  art.rgb*=.98+.025*sin(p.x*.045+p.y*.035+TIME*.7);
  art.rgb+=vec3(.04,.055,.06)*smoothstep(.87,1.,ripple);
 }
 COLOR=art*tint;
}
