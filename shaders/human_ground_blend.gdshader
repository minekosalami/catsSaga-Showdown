shader_type canvas_item;
// Remove only the old Kenney grass mat around placed props; human art stays intact.
void fragment() {
 vec4 pixel = texture(TEXTURE, UV);
 vec3 old_grass = vec3(141.0,196.0,53.0)/255.0;
 vec3 old_speckle = vec3(132.0,187.0,44.0)/255.0;
 if (distance(pixel.rgb,old_grass)<0.003 || distance(pixel.rgb,old_speckle)<0.003) discard;
}
