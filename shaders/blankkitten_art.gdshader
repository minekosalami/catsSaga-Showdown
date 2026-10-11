shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float corruption=0.0;
uniform float intensity=1.0;
uniform float flash=0.0;
void fragment(){
 float row=floor(UV.y*64.0);
 float burst=step(.91,fract(sin(row*127.1+floor(clock*6.0)*311.7)*43758.5453));
 vec2 uv=UV+vec2(burst*sin(clock*7.0)*.009*corruption*intensity,0);
 vec4 c=texture(TEXTURE,uv);
 float shift=.0015*corruption*intensity;
 c.r=mix(c.r,texture(TEXTURE,uv+vec2(shift,0)).r,.45*intensity);
 c.b=mix(c.b,texture(TEXTURE,uv-vec2(shift,0)).b,.45*intensity);
 c.rgb=mix(c.rgb,vec3(dot(c.rgb,vec3(.299,.587,.114))),corruption*.12);
 c.rgb+=flash*.3;
 COLOR=c;
}
