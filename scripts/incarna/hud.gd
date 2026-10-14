extends CanvasLayer
const Cfg = preload("res://scripts/incarna/config.gd")
var battle: Node
var root: Control
var health: Label
var timer: Label
var controls: Label
var title: Label
var stamina: ProgressBar
var result: Control
var result_label: Label
var return_button: Button
var retry_button: Button
var main_menu_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	title = label("INCARNA()",Rect2(30,20,400,40),30)
	label("ENDURE()",Rect2(32,62,220,24),13)
	timer = label("",Rect2(1030,22,220,35),25)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health = label("",Rect2(24,695,210,24),15)
	controls = label("",Rect2(360,695,680,24),12)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamina = ProgressBar.new()
	stamina.position = Vector2(230,704)
	stamina.size = Vector2(110,6)
	stamina.min_value = 0
	stamina.max_value = 1
	preload("res://scripts/ui/battle_hud_style.gd").progress(stamina,Color.WHITE)
	root.add_child(stamina)
	var reduced := CheckButton.new()
	reduced.text = "Reduced FX"
	reduced.position = Vector2(1080,690)
	reduced.size = Vector2(175,28)
	reduced.add_theme_font_size_override("font_size",12)
	reduced.button_pressed = battle.reduced_effects
	reduced.toggled.connect(func(value: bool):
		battle.reduced_effects = value
		Session.set_meta("incarna_reduced_fx",value)
	)
	root.add_child(reduced)
	result = Control.new()
	result.set_script(preload("res://scripts/ui/cinematic_result.gd"))
	var look: Resource = load("res://resources/battle/doppelcat.tres").duplicate()
	look.accent = Color("#EAEAEA")
	result.look = look
	root.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	result.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.name = "VBoxContainer"
	column.add_theme_constant_override("separation",18)
	center.add_child(column)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size",46)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_label)
	var message := Label.new()
	message.name = "Message"
	message.text = "Incarna endured."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	return_button = button(column,"RETURN TO CAVE",func(): battle.get_tree().current_scene.return_to_forest())
	retry_button = button(column,"RETRY",func(): battle.get_tree().current_scene.retry())
	main_menu_button = button(column,"MAIN MENU",func(): battle.get_tree().current_scene.main_menu())
	result.hide()

func label(text: String, rect: Rect2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_constant_override("outline_size",4)
	node.add_theme_color_override("font_outline_color",Color.BLACK)
	root.add_child(node)
	return node

func button(column: VBoxContainer,text: String,action: Callable) -> Button:
	var node := Button.new()
	node.set_script(preload("res://scripts/ui/sketch_button.gd"))
	node.text = text
	node.custom_minimum_size = Vector2(360,50)
	column.add_child(node)
	node.pressed.connect(action)
	return node

func update_clock(time: float) -> void:
	if health == null: return
	health.text = "● ".repeat(battle.player.health)+"○ ".repeat(maxi(0,3-battle.player.health))
	health.modulate = Color("#FF786E") if battle.player.health == 1 else Color.WHITE
	var remaining := maxf(0,Cfg.END-time)
	timer.text = "%02d:%05.2f" % [int(remaining)/60,fmod(remaining,60)]
	stamina.value = battle.player.stamina
	controls.text = "…" if time < Cfg.EMERGENCE else "WASD / ARROWS  MOVE   ·   SHIFT  FOCUS   ·   X  SPRINT"
	title.modulate.a = 1-smoothstep(10,16,time)

func show_result(won: bool) -> void:
	result_label.text = "ENDURED()" if won else "DEFEAT()"
	result.get_node("CenterContainer/VBoxContainer/Message").text = "Incarna endured." if won else "The underground holds its breath."
	return_button.visible = won
	result.modulate.a = 0
	result.show()
	create_tween().tween_property(result,"modulate:a",1.0,.65)
	(return_button if won else retry_button).grab_focus()
