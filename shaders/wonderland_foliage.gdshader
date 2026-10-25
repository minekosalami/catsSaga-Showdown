shader_type canvas_item;
uniform float motion = 1.0;
uniform float strength = 1.0;
uniform float height = 96.0;
uniform bool tile_motion = false;
void vertex() {
 float phase=MODEL_MATRIX[3].x*.017+MODEL_MATRIX[3].y*.023;
 float top=clamp(-VERTEX.y/height,0.0,1.0);
 if(tile_motion){phase+=floor(VERTEX.x/32.0)*.73+floor(VERTEX.y/32.0)*.57;top=.6;}
 VERTEX.x+=sin(TIME*(.65+mod(phase,.35))+phase)*top*strength*motion;
 VERTEX.y+=sin(TIME*.8+phase)*top*.3*motion;
}
