shader_type canvas_item;
uniform float clock = 0.0;
uniform float energy = 0.0;
uniform float bass = 0.0;
uniform float detail = 0.0;
uniform float section = 0.0;
uniform float motion = 0.8;
uniform float reduced = 0.0;
uniform int identity = 0;
uniform bool boss_active = false;
uniform vec4 arena = vec4(0.0,0.0,1.0,1.0);
uniform sampler2D floor_sheet : filter_nearest;
void fragment() {
 vec2 uv = UV;
 float t = clock*motion*(1.0-reduced*.7);
 vec2 p = (uv-vec2(.5,.30))*vec2(1.0,1.66);
 float r = length(p);
 float angle = atan(p.y,p.x);
 float phase = boss_active ? section : 0.0;
 vec3 ink = vec3(.012,.018,.031);
 vec3 a = identity==0 ? vec3(.85,.12,.32) : (identity==1 ? vec3(.08,.62,.88) : vec3(.91,.27,.63));
 vec3 b = identity==0 ? vec3(.32,.15,.65) : (identity==1 ? vec3(.20,.22,.65) : vec3(.45,.22,.83));
 // Human woodland pixels ground the quiet opening. No reaction before the boss.
 vec2 tile = fract(uv*vec2(17.0,28.0));
 vec3 grass = texture(floor_sheet,(vec2(11.0,12.0)+tile)/vec2(22.0,26.0625)).rgb;
 vec3 color = ink+grass*(boss_active ? .018 : .09);
 float petals = 0.0;
 float rings = 0.0;
 float threads = 0.0;
 if(identity==0) {
  float fold = sin(angle*(6.0+floor(phase*2.0))+r*12.0-t*.22);
  petals = pow(max(0.0,1.0-abs(r-(.20+fold*.12+sin(t*.12)*.025))*12.0),3.0);
  rings = pow(.5+.5*sin(r*49.0-angle*3.0+t*.45+sin(angle*5.0+t*.1)),10.0);
  threads = pow(.5+.5*sin(p.x*36.0+sin(p.y*8.0+t*.16)*4.0),28.0);
 } else if(identity==1) {
  vec2 mirror = vec2(abs(p.x),p.y);
  float ripple = sin(mirror.x*17.0+mirror.y*8.0-t*.7)*.035;
  rings = pow(.5+.5*sin((r+ripple)*55.0-t*.55),14.0);
  petals = pow(max(0.0,1.0-abs(r-(.22+sin(angle*4.0+t*.12)*.07))*16.0),2.0);
  threads = pow(.5+.5*sin((mirror.x+sin(mirror.y*5.0+t*.09)*.10)*61.0),22.0);
 } else {
  vec2 q = p;
  for(int i=0;i<3;i++) { q = abs(q)*1.55-vec2(.28,.22); q=vec2(q.x*.949235-q.y*.314567,q.x*.314567+q.y*.949235); }
  threads = pow(max(0.0,1.0-length(q)*3.4),3.0);
  rings = pow(.5+.5*sin(r*62.0-angle*5.0+t*.4),18.0);
  petals = pow(max(0.0,cos(angle*5.0+t*.10)),10.0)*exp(-abs(r-.3)*9.0);
 }
 // Visual escalation follows authored musical sections; FFT adds texture only.
 float movement = boss_active ? (.18+phase*.55) : .035;
 float edge = pow(abs(uv.x-.5)*2.0,3.0);
 float upper = 1.0-smoothstep(.25,.90,uv.y);
 vec3 hue = mix(a,b,.5+.5*sin(angle*2.0+t*.08));
 float canopy = 1.0-smoothstep(.35,.65,uv.y);
 float climactic = smoothstep(.55,1.0,phase);
 color += hue*(rings*.16+petals*.42+threads*.17)*movement*(.65+canopy*.8);
 // Ribbon bands unfurl through the authored climax, outside the dodging floor.
 float ribbon = pow(.5+.5*sin(angle*7.0-r*23.0+t*.25+sin(angle*3.0-t*.1)),15.0);
 color += mix(a,b,r)*ribbon*climactic*.13*canopy;
 color += a*(.025+phase*.035+bass*.014)*(edge+upper*.2);
 color += b*detail*.025*petals;
 float inside = step(arena.x,uv.x)*step(uv.x,arena.x+arena.z)*step(arena.y,uv.y)*step(uv.y,arena.y+arena.w);
 // Keep the dodging floor dim and still readable through every climax.
 color *= mix(1.0,.58,inside*smoothstep(.32,.55,uv.y));
 color += hue*energy*.012*(1.0-reduced*.8);
 COLOR = vec4(clamp(color,vec3(0.0),vec3(.29)),1.0);
}
