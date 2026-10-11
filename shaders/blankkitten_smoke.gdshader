shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float distortion=0.0;
uniform float inferno=0.0;
uniform float strength=1.0;
uniform float resolution=0.0;
uniform bool foreground=false;
uniform vec4 arena=vec4(70.0,440.0,400.0,320.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.57+noise(p*2.07)*.28+noise(p*4.17)*.15;}
void fragment(){
 vec2 uv=UV; float beat=pow(1.0-fract(clock/(60.0/140.0)*.25),9.0);
 float glitch=step(.93,noise(vec2(floor(uv.y*80.0),floor(clock*3.0))));
 uv.x+=glitch*sin(clock*9.0)*.006*distortion*strength;
 vec2 curl=vec2(noise(uv*6.0+clock*.06),noise(uv*7.0-clock*.07))-.5;
 float rear=fbm(uv*vec2(5.0,7.0)+vec2(clock*.04,-clock*.085)+curl);
 float mid=fbm(uv*vec2(8.0,5.0)+vec2(-clock*.055,-clock*.12)-curl*1.4);
 float front=fbm(uv*vec2(3.0,4.0)+vec2(clock*.035,-clock*.045)+curl*2.0);
 float edges=smoothstep(.1,.47,abs(uv.x-.5));
 float density=(rear*.45+mid*.35+front*.2)*(.15+distortion*.06+inferno*.45)*(1.0-resolution*.85);
 vec3 cold=mix(vec3(.12,.16,.23),vec3(.18,.17,.2),distortion/3.0);
 vec3 light=vec3(.65,.19,.07)*inferno*(.6+beat*.15);
 vec3 smoke=cold+light*(edges+.2)*rear;
 float halo=exp(-length((uv-vec2(.5,.245))*vec2(3.0,4.0))*2.5);
 vec3 color=vec3(.023,.028,.043)+smoke*density+vec3(.055,.065,.09)*halo;
 color=mix(color,vec3(dot(color,vec3(.299,.587,.114))),clamp(distortion*.22,0.0,.66));
 color+=light*edges*.07;
 float scan=sin(uv.y*900.0)*.003*distortion*strength;
 if(foreground){
 vec2 pixel=UV*vec2(540.0,900.0);
 bool inside=pixel.x>arena.x-8.0 && pixel.x<arena.x+arena.z+8.0 && pixel.y>arena.y-8.0 && pixel.y<arena.y+arena.w+8.0;
 float plume=smoothstep(.28,.70,front*.6+mid*.4);
 float opacity=plume*(.10+inferno*.75+distortion*.055)*strength*(1.0-resolution*.9);
 COLOR=vec4(mix(vec3(.075,.085,.11),vec3(.19,.14,.13),inferno),inside?0.0:opacity);
 }else{COLOR=vec4(color+scan,1.0);}
}
