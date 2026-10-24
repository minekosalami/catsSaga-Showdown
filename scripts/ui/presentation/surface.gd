extends PanelContainer
const Style=preload("res://scripts/ui/presentation/style.gd")
@export var accent:=Style.MINT
var clock:=0.0
var redraw_wait:=0.0
func _ready() -> void:
	add_theme_stylebox_override("panel",Style.box(Style.INK,accent))
func _process(delta: float) -> void:
	clock+=delta;redraw_wait-=delta
	if redraw_wait<=0:redraw_wait=.05;queue_redraw()
func _draw() -> void:
	var reduced: bool=get_node("/root/VisualSettings").reduced
	var pulse:=.18 if reduced else .18+.05*sin(clock*1.6)
	draw_rect(Rect2(2,2,size.x-4,5),Color(accent,pulse))
	for corner in [Vector2(10,10),Vector2(size.x-10,size.y-10)]:
		var signum:=1.0 if corner.x<size.x*.5 else -1.0
		draw_line(corner,corner+Vector2(28*signum,0),accent,2)
		draw_line(corner,corner+Vector2(0,12*signum),accent,2)
	for i in 5:draw_line(Vector2(size.x-66+i*8,12),Vector2(size.x-62+i*8,16),Color(accent,.35),1)
	draw_line(Vector2(14,size.y-10),Vector2(size.x-14,size.y-10),Color(accent,.1),1)
