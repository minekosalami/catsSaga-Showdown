shader_type canvas_item;
render_mode unshaded;
uniform float opacity=.14;
void vertex(){VERTEX.x-=VERTEX.y*.48;VERTEX.y=-VERTEX.y*.16;}
void fragment(){vec4 art=texture(TEXTURE,UV);COLOR=vec4(.16,.12,.23,art.a*opacity);}
