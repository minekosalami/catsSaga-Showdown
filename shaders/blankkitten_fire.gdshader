shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);
}
void fragment() {
 vec2 p=UV*vec2(6.0,5.0);
 p.y+=clock*1.65;
 float n=noise(p)*0.56+noise(p*2.1+vec2(clock*0.15,0))*0.29+noise(p*4.3)*0.15;
 float tongue=(1.0-UV.y)*1.35+(1.0-n)*0.78;
 float flame=1.0-smoothstep(0.42,1.04,tongue);
 vec3 fire=mix(vec3(0.42,0.025,0.015),vec3(1.0,0.3,0.035),flame);
 fire=mix(fire,vec3(1.0,0.82,0.36),pow(flame,4.0));
 COLOR=vec4(fire,flame*intensity*0.65);
}
