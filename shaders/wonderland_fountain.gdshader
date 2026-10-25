shader_type canvas_item;
uniform float motion=1.0;
void fragment(){
 vec4 art=texture(TEXTURE,UV);
 if(distance(art.rgb,vec3(141.0,196.0,53.0)/255.0)<.003 || distance(art.rgb,vec3(132.0,187.0,44.0)/255.0)<.003)discard;
 if(art.b>art.r+.12 && art.g>art.r+.12){
  float shift=sin(floor(TIME*5.0)*.35+UV.y*80.0)*TEXTURE_PIXEL_SIZE.x*motion;
  vec4 ripple=texture(TEXTURE,UV+vec2(shift,0.0));
  if(ripple.b>ripple.r+.12)art=mix(art,ripple,.6);
  art.rgb*=1.0+.035*sin(TIME*2.0+UV.x*90.0)*motion;
 }
 COLOR*=art/ max(texture(TEXTURE,UV),vec4(.001));
}
