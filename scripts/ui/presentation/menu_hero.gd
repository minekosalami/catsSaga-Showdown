extends Control
const Style=preload("res://scripts/ui/presentation/style.gd")
var portrait: TextureRect
var clock:=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait=TextureRect.new();portrait.texture=preload("res://assets/player/player.png.png")
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position=Vector2(100,208);portrait.size=Vector2(300,280);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
func _process(delta: float) -> void:
	clock+=delta*(.15 if get_node("/root/VisualSettings").reduced else .8)
	portrait.position.y=208+sin(clock)*5
	queue_redraw()
func _draw() -> void:
	var center:=Vector2(250,350)
	draw_circle(center,133,Color(Style.MINT,.055))
	for i in 3:draw_arc(center,130+i*12,clock*.05+i*1.9,clock*.05+i*1.9+1.25,40,Color(Style.GOLD if i==0 else Style.LILAC,.25),2,true)
	draw_line(Vector2(42,530),Vector2(420,530),Color(Style.MINT,.4),1)
	for i in 8:draw_rect(Rect2(42+i*12,540,6,3),Color(Style.CORAL,.18+i*.05))
