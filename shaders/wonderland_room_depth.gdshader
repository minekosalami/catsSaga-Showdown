shader_type canvas_item;
uniform vec4 floor_rooms[24];
uniform int room_count=0;
varying vec2 world;
varying vec4 tint;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;tint=COLOR;}
bool floor_at(vec2 p){
 for(int i=0;i<24;i++){
  if(i>=room_count)break;
  vec4 r=floor_rooms[i];
  if(p.x>=r.x && p.y>=r.y && p.x<r.x+r.z && p.y<r.y+r.w)return true;
 }
 return false;
}
void fragment(){
 vec2 p=floor(world/2.0)*2.0;
 float shade=1.0;
 if(!floor_at(p-vec2(0.0,8.0)))shade*=.78;
 else if(!floor_at(p-vec2(0.0,24.0)))shade*=.92;
 if(!floor_at(p-vec2(8.0,0.0)))shade*=.88;
 COLOR=texture(TEXTURE,UV)*tint*vec4(vec3(shade),1.0);
}
