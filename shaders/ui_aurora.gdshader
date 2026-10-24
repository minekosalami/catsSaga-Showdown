shader_type canvas_item;
uniform float motion=1.;
void fragment(){
	vec2 p=UV;
	float t=TIME*motion;
	vec3 ink=mix(vec3(.027,.045,.09),vec3(.065,.105,.17),1.-p.y);
	float a=sin(p.x*5.+p.y*3.+t*.06)*.06+.25;
	float b=sin(p.x*6.-p.y*4.-t*.05)*.06+.72;
	float glow=exp(-abs(p.y-a)*16.);
	float pink=exp(-abs(p.y-b)*15.);
	vec3 color=ink+vec3(.04,.22,.20)*glow+vec3(.19,.04,.13)*pink;
	float grid=step(.995,fract(p.x*36.))*step(.6,p.y)+step(.995,fract(p.y*22.))*.25;
	color+=grid*.014;
	COLOR=vec4(color,1.);
}
