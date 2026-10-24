extends RefCounted
## Shared presentation only; no gameplay values or asset generation.
const INK=Color("#101a2c")
const DEEP=Color("#080e1c")
const PAPER=Color("#f7f0dc")
const MUTED=Color("#9aaac2")
const MINT=Color("#74e7cf")
const CORAL=Color("#ff8b9d")
const GOLD=Color("#ffda7e")
const LILAC=Color("#c2a6ff")
const FONT=preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
const BOLD=preload("res://assets/ui/fonts/DejaVuSansMono-Bold.ttf")
const DISPLAY=preload("res://assets/ui/fonts/DejaVuSerifCondensed.ttf")
static func box(fill: Color=INK, edge: Color=MINT, width:=1, padding:=12) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=fill;result.border_color=Color(edge,.55)
	result.set_border_width_all(width)
	result.border_width_bottom=2
	result.set_corner_radius_all(9)
	result.corner_radius_top_left=3;result.corner_radius_bottom_right=3
	result.set_content_margin_all(padding)
	result.shadow_color=Color(DEEP,.75);result.shadow_size=6;result.shadow_offset=Vector2(0,5)
	return result
static func theme() -> Theme:
	var result:=Theme.new();result.default_font=FONT;result.default_font_size=16
	for type in ["Label","RichTextLabel","Button","CheckButton","OptionButton","TabContainer"]:
		result.set_color("font_color",type,PAPER)
		result.set_color("font_hover_color",type,Color.WHITE)
		result.set_color("font_focus_color",type,GOLD)
		result.set_color("font_disabled_color",type,MUTED*.75)
	for type in ["Button","OptionButton"]:
		result.set_stylebox("normal",type,box(Color("#1b2940"),Color("#526786")))
		result.set_stylebox("hover",type,box(Color("#28465a"),MINT,2))
		result.set_stylebox("pressed",type,box(Color("#32445e"),GOLD,2))
		result.set_stylebox("disabled",type,box(Color("#131e30"),Color("#35435b")))
		result.set_stylebox("focus",type,box(Color.TRANSPARENT,GOLD,2))
	for type in ["PanelContainer","PopupMenu","AcceptDialog","TabContainer"]:result.set_stylebox("panel",type,box())
	result.set_color("default_color","RichTextLabel",PAPER)
	result.set_font("normal_font","RichTextLabel",FONT);result.set_font("bold_font","RichTextLabel",BOLD)
	for type in ["VScrollBar","HScrollBar"]:
		result.set_stylebox("scroll",type,box(DEEP,Color("#31435d"),1,2))
		for state in ["grabber","grabber_highlight","grabber_pressed"]:result.set_stylebox(state,type,box(Color("#496580"),MINT,1,4))
	for type in ["HSlider","VSlider"]:
		result.set_stylebox("slider",type,box(DEEP,Color("#496580"),1,3))
		result.set_stylebox("grabber_area",type,box(MINT,MINT,0,3))
	var track:=box(DEEP,Color("#3e546e"),1,0)
	result.set_stylebox("background","ProgressBar",track)
	result.set_stylebox("fill","ProgressBar",box(MINT,MINT,0,0))
	for state in ["tab_selected","tab_unselected","tab_hovered"]:
		result.set_stylebox(state,"TabBar",box(INK if state=="tab_unselected" else Color("#29445a"),MINT))
	var window:=box(INK,LILAC);window.content_margin_top=34
	result.set_stylebox("embedded_border","Window",window)
	result.set_stylebox("embedded_unfocused_border","Window",window)
	return result
static func grade_color(grade: String) -> Color:
	return {"S+":GOLD,"A+":MINT,"A":Color("#77caff"),"B":LILAC,"C":Color("#e5b2db"),"D":Color("#ffb67f"),"F":CORAL}.get(grade,PAPER)
static func label(parent: Node, text: String, font_size:=16, tint:=PAPER) -> Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",tint);parent.add_child(node);return node
static func burst(parent: Node, point: Vector2, tint: Color, count:=16) -> CPUParticles2D:
	if not parent.is_inside_tree():return null
	var particles:=CPUParticles2D.new()
	parent.add_child(particles);particles.position=point;particles.one_shot=true;particles.explosiveness=1
	particles.amount=count;particles.lifetime=.48;particles.spread=180;particles.gravity=Vector2(0,60)
	particles.initial_velocity_min=25;particles.initial_velocity_max=115;particles.scale_amount_min=1;particles.scale_amount_max=3;particles.color=tint
	particles.emitting=not parent.get_node("/root/VisualSettings").reduced
	var weak: WeakRef=weakref(particles)
	parent.get_tree().create_timer(.7).timeout.connect(func():
		var node=weak.get_ref()
		if node!=null:node.queue_free())
	return particles
static func pop(node: Control, amount:=1.04, duration:=.22) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree():return null
	node.pivot_offset=node.size*.5;node.scale=Vector2.ONE*amount
	var tween:=node.create_tween()
	tween.tween_property(node,"scale",Vector2.ONE,duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween
