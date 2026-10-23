shader_type canvas_item;
uniform float strength = 1.0;
void vertex() {
 // Fixed lower trunk; only the upper artwork moves. Alpha is never reduced.
 float canopy = pow(1.0-UV.y,2.0);
 VERTEX.x += sin(TIME*0.8+MODEL_MATRIX[3].x*.017+UV.y*2.0)*canopy*strength;
}
