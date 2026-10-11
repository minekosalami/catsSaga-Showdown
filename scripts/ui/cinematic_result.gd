extends Control
# Existing result screens keep their labels, actions and navigation. This
# component supplies only a common animated background and framing treatment.
var look: Resource
var age := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if is_visible_in_tree():
		age += delta
		queue_redraw()
func _draw() -> void:
	var tint: Color = look.accent if look != null else Color("#69DAF4")
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.021,0.035,0.97))
	var center := size*Vector2(0.5,0.4)
	for i in range(3):
		var radius := 130.0+i*42+sin(age*0.5+i)*3
		for j in range(4):
			var angle := j*PI/2+age*0.05*(1 if i%2 else -1)
			draw_arc(center,radius,angle,angle+1.1,36,Color(tint,0.07-i*0.012),1,true)
	draw_rect(Rect2(16,16,size.x-32,size.y-32),Color(tint,0.32),false,1,true)
	for i in range(16):
		var p := Vector2(32+fposmod(i*71.0,size.x-64),fposmod(i*67.0-age*(4+i%4),size.y))
		draw_line(p,p+Vector2(0,3),Color(tint,0.12),1,true)
