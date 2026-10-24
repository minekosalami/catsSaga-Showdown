shader_type canvas_item;
uniform float wind = 0.3;
void vertex() {
	float canopy=clamp((-VERTEX.y+20.0)/80.0,0.0,1.0);
	VERTEX.x+=sin(TIME*(.7+wind*.3)+MODEL_MATRIX[3].x*.017)*canopy*(.4+wind*1.5);
}
