shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float reduced=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.0; float r=length(p); float a=atan(p.y,p.x);
 float turbulent=noise(p*7.0+vec2(clock*.8,-clock*1.9));
 float tongue=sin(a*13.0-clock*5.0)*.03+sin(a*23.0+clock*3.0)*.02;
 float flame=1.0-smoothstep(.70+turbulent*.2+ tongue,.98,r);
 float core=1.0-smoothstep(.15,.77,r);
 vec3 color=mix(vec3(.7,.07,.015),vec3(1.0,.39,.035),flame);
 color=mix(color,vec3(1.0,.91,.58),core*core*.95);
 color+=vec3(.15,.12,.01)*noise(vec2(a*5.0+r*8.0-clock*3.0,r*11.0-clock*2.0));
 float rim=1.0-smoothstep(.004,.013,abs(r-73.0/85.0));
 color=mix(color,vec3(1.0,.84,.43),rim*.6);
 float halo=(1.0-smoothstep(.45,1.0,r))*.28*(1.0-reduced*.6);
 COLOR=vec4(color,max(flame,halo));
}
