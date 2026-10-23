shader_type canvas_item;
render_mode unshaded;
uniform vec2 display_size = vec2(64.0);
uniform float pixel_size = 2.0;
uniform float grayscale = 0.0;
varying vec4 modulation;
void vertex() {modulation = COLOR;}
void fragment() {
 // Sample the supplied artwork on a stable display grid. Source files are intact.
 vec2 grid = max(vec2(1.0), floor(display_size / pixel_size));
 vec2 uv = (floor(UV * grid) + .5) / grid;
 vec4 sample_color = texture(TEXTURE, clamp(uv,vec2(0.0),vec2(1.0)));
 sample_color.rgb = mix(sample_color.rgb,vec3(dot(sample_color.rgb,vec3(.299,.587,.114))),grayscale);
 COLOR = modulation * sample_color;
}
