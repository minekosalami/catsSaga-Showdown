shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform vec2 arena_size=vec2(340.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
void fragment(){
 vec2 p=UV*arena_size;
 float edge=min(min(p.x,arena_size.x-p.x),min(p.y,arena_size.y-p.y));
 float along=min(p.x,arena_size.x-p.x)<min(p.y,arena_size.y-p.y)?p.y:p.x;
 float n=noise(vec2(along*.13-clock*.7,edge*.25-clock*3.0));
 // Opaque flames end at the exact nine-pixel contact band; only dim heat glow extends beyond it.
 float flame=1.0-smoothstep(7.0+n*1.2,9.0,edge);
 float halo=(1.0-smoothstep(9.0,13.0,edge))*.07;
 float core=1.0-smoothstep(2.0,9.0,edge);
 vec3 color=mix(vec3(1.0,.19,.025),vec3(1.0,.83,.4),core);
 color*=.8+n*.2;
 COLOR=vec4(color,max(flame,halo));
}
