extends Button
const Style=preload("res://scripts/ui/presentation/style.gd")
var hover_amount:=0.0
var clock:=0.0
func _ready() -> void:
	resized.connect(func():pivot_offset=size*.5)
	pressed.connect(func():Style.pop(self,.97,.14))
func _process(delta: float) -> void:
	clock+=delta
	var target:=1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
	hover_amount=lerpf(hover_amount,target,1-exp(-delta*16))
	queue_redraw()
func _draw() -> void:
	if hover_amount<.01:return
	var x:=14+hover_amount*3
	draw_polyline(PackedVector2Array([Vector2(x,size.y*.5-5),Vector2(x+5,size.y*.5),Vector2(x,size.y*.5+5)]),Color(Style.GOLD,hover_amount),2)
	draw_line(Vector2(28,size.y-5),Vector2(28+(size.x-56)*hover_amount,size.y-5),Color(Style.MINT,.65*hover_amount),2)
