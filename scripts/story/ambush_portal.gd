extends Node2D
## Procedural portal/explosion effects only. No texture artwork is generated.
var burst := 0.0
var clock := 0.0
func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()
func _draw() -> void:
	if burst>0:
		for i in 3:
			draw_arc(Vector2.ZERO,20+burst*(240+i*55),0,TAU,64,Color(1,.65+i*.1,.95,1-burst),8-i*2)
		for i in 24:
			var direction:=Vector2.from_angle(i*TAU/24)
			draw_line(direction*burst*190,direction*burst*330,Color(1,.9,1,1-burst),3)
	else:
		draw_circle(Vector2.ZERO,43,Color(.09,.02,.16,.95))
		for i in 3:
			draw_arc(Vector2.ZERO,44+i*5,clock*(1+i*.2),clock*(1+i*.2)+TAU*.85,48,Color(1,.5+i*.2,1),3)
