extends ProgressBar
## The Range value stays exact for game/tests. Only rendered fill interpolates.
@export var tint:=Color("#74e7cf")
var shown:=0.0
var ghost:=0.0
var initialized:=false
var track: StyleBoxFlat
func _ready() -> void:
	show_percentage=false
	track=preload("res://scripts/ui/presentation/style.gd").box(Color("#070f20"),Color("#48617a"),1,0)
	var empty:=StyleBoxEmpty.new()
	add_theme_stylebox_override("background",empty);add_theme_stylebox_override("fill",empty)
	custom_minimum_size.y=12
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	var target:=clampf((value-min_value)/maxf(.001,max_value-min_value),0,1)
	if not initialized:shown=target;ghost=target;initialized=true
	shown=lerpf(shown,target,1-exp(-delta*14))
	ghost=lerpf(ghost,target,1-exp(-delta*3.5))
	queue_redraw()
func _draw() -> void:
	draw_style_box(track,Rect2(Vector2.ZERO,size))
	var rect:=Rect2(2,2,maxf(0,(size.x-4)*maxf(shown,ghost)),maxf(0,size.y-4))
	draw_rect(rect,Color("#ffdc9a"))
	rect.size.x=maxf(0,(size.x-4)*shown)
	draw_rect(rect,tint)
	if rect.size.x>1:draw_line(Vector2(3,3),Vector2(rect.end.x,3),Color.WHITE*.8,1)
	for i in range(1,10):draw_line(Vector2(size.x*i/10.0,2),Vector2(size.x*i/10.0,size.y-2),Color("#101a2c66"),1)
