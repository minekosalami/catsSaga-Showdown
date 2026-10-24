extends Label
const Style=preload("res://scripts/ui/presentation/style.gd")
var backdrop: StyleBoxFlat
var text_width:=0.0
var cached:=""
var accent:=Style.MINT
func _ready() -> void:
	custom_minimum_size.y=44;vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color",Style.PAPER)
	add_theme_font_size_override("font_size",17)
	backdrop=Style.box(Color("#152d41f5"),Style.MINT,1,12)
	add_theme_stylebox_override("normal",backdrop)
	modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,.18)
func _process(_delta: float) -> void:
	if cached==text:return
	cached=text;accent=Style.CORAL if text.begins_with("Insufficient") or text.begins_with("Cannot") else Style.MINT
	backdrop.border_color=Color(accent,.65)
	text_width=get_theme_font("font").get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,get_theme_font_size("font_size")).x
	var width:=minf(get_viewport_rect().size.x-32,text_width+72)
	anchor_left=.5;anchor_right=.5;offset_left=-width*.5;offset_right=width*.5
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2(15,size.y*.5),3,accent)
