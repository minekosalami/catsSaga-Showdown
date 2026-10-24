extends Control
const Style=preload("res://scripts/ui/presentation/style.gd")
var clock:=0.0
var points: Array[Vector3]=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var rng:=RandomNumberGenerator.new();rng.seed=4461
	for i in 32:points.append(Vector3(rng.randf(),rng.randf(),rng.randf()*TAU))
func _process(delta: float) -> void:
	clock+=delta*(.1 if get_node("/root/VisualSettings").reduced else .5)
	queue_redraw()
func _draw() -> void:
	for i in points.size():
		var p:=points[i]
		var point:=Vector2(fposmod(p.x+clock*.004,1)*size.x,fposmod(p.y-clock*.006,1)*size.y)
		draw_circle(point,1.5,Color(Style.MINT if i%2 else Style.CORAL,.12+.08*sin(clock+p.z)))
	for i in 4:
		var origin:=Vector2(size.x*(.07+i*.28),size.y*(.17+.17*sin(i+clock*.08)))
		draw_arc(origin,46+i*23,clock*.05,clock*.05+1.7,22,Color(Style.LILAC,.1),1,true)
