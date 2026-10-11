shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float intensity : hint_range(0.0,1.0)=0.0;
uniform float strength=1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.55+noise(p*2.05)*.3+noise(p*4.17)*.15;}
void fragment(){
 vec2 uv=UV; float beat=pow(1.0-fract(clock/(60.0/140.0)*.25),8.0);
 vec2 curl=vec2(noise(uv*7.0+clock*.15),noise(uv*6.0-clock*.12))-.5;
 vec2 p=uv*vec2(7.0,4.0)+curl*.8;
 float rear=fbm(p+vec2(clock*.12,-clock*1.6));
 float near=fbm(p*1.7+vec2(-clock*.09,-clock*2.1));
 float sides=smoothstep(.08,.43,abs(uv.x-.5));
 float height=mix(.40,.77,intensity)+sides*.15;
 float field=(1.0-uv.y)/height;
 float flames=1.0-smoothstep(.2,.88,field-rear*.43-near*.28+sin(uv.x*19.0+clock*.7)*.07);
 float core=pow(clamp(flames,0.0,1.0),3.0);
 vec3 color=mix(vec3(.32,.015,.025),vec3(1.0,.23,.025),flames);
 color=mix(color,vec3(1.0,.86,.38),core*.8);
 float halo=(rear+near)*sides*.08;
 COLOR=vec4(color,clamp((flames*.58+halo)*(intensity)*( .75+beat*.08)*mix(.55,1.0,strength),0.0,.85));
}
