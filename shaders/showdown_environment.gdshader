shader_type canvas_item;
uniform sampler2D grass : filter_nearest;
uniform sampler2D water : filter_nearest;
uniform vec4 atmosphere : source_color = vec4(.16,.35,.29,1.);
uniform float flooded=0.;
uniform float motion=1.;
void fragment(){
	vec2 p=UV;
	vec2 cell=fract(p*vec2(9.,15.));
	vec2 uv=vec2(32.,160.)/vec2(96.,192.)+cell*vec2(32.,32.)/vec2(96.,192.);
	vec3 ground=texture(grass,uv).rgb;
	float t=TIME*motion;
	vec2 wuv=fract(p*vec2(3.,7.)+vec2(sin(p.y*18.+t*.3)*.008,t*.002));
	vec3 wet=texture(water,(vec2(32.,160.)+wuv*32.)/vec2(96.,192.)).rgb;
	float wet_mask=smoothstep(.22,.32,p.y+sin(p.x*5.+t*.025)*.04)*flooded;
	vec3 base=mix(ground*.12,wet*.12,wet_mask);
	base=mix(base,atmosphere.rgb,.24);
	float mist=(sin(p.x*6.+p.y*9.+t*.12)*.5+.5)*.018;
	float shaft=pow(max(0.,sin((p.x+p.y*.27)*21.+t*.05)),16.)*.018*(1.-flooded);
	float center=smoothstep(.8,.12,length((p-.5)*vec2(1.,.65)));
	COLOR=vec4(base*(.65+center*.35)+mist+shaft,1.);
}
