shader_type canvas_item;
void fragment(){
 // Walls remain solid collision geometry; dark masonry outside the cutaway is restrained.
 vec4 art=texture(TEXTURE,UV);
 float shade=dot(art.rgb,vec3(.2126,.7152,.0722));
 COLOR=vec4(vec3(.055,.037,.065)+shade*.012,art.a);
}
