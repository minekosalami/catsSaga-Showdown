extends CanvasLayer

var health_label: Label
var timer_label: Label
var phase_label: Label
var dialogue_label: Label
var saturate_label: Label
var end_screen: Control
var result_label: Label
var return_button: Button
var battle: Node
var phase_tween: Tween

func _ready() -> void:
	battle = get_parent()
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",22)
	panel.add_child(row)
	health_label = Label.new()
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(health_label)
	timer_label = Label.new()
	row.add_child(timer_label)
	phase_label = Label.new()
	root.add_child(phase_label)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	phase_label.offset_top = 72
	phase_label.offset_bottom = 112
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size",24)
	phase_label.add_theme_color_override("font_outline_color",Color.BLACK)
	phase_label.add_theme_constant_override("outline_size",5)
	dialogue_label = Label.new()
	root.add_child(dialogue_label)
	dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	dialogue_label.offset_left = 42
	dialogue_label.offset_right = -42
	dialogue_label.offset_top = 275
	dialogue_label.offset_bottom = 365
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size",20)
	dialogue_label.add_theme_color_override("font_outline_color",Color.BLACK)
	dialogue_label.add_theme_constant_override("outline_size",5)
	saturate_label = Label.new()
	root.add_child(saturate_label)
	saturate_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	saturate_label.offset_top = -42
	saturate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saturate_label.add_theme_font_size_override("font_size",18)
	saturate_label.add_theme_color_override("font_outline_color",Color.BLACK)
	saturate_label.add_theme_constant_override("outline_size",5)
	end_screen = ColorRect.new()
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_screen.color = Color(0.02,0.03,0.05,0.95)
	var center := CenterContainer.new()
	end_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",20)
	center.add_child(content)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size",40)
	content.add_child(result_label)
	for action in ["RETURN TO FLOODED FOREST","RETRY","MAIN MENU"]:
		var button := Button.new()
		button.set_script(preload("res://scripts/ui/sketch_button.gd"))
		button.text = action
		button.custom_minimum_size = Vector2(410,56)
		content.add_child(button)
		if action.begins_with("RETURN"):
			return_button = button
			button.pressed.connect(func(): get_tree().current_scene.return_to_forest())
		elif action == "RETRY":
			button.pressed.connect(func(): get_tree().current_scene.retry())
		else:
			button.pressed.connect(func(): get_tree().current_scene.main_menu())
	end_screen.hide()

func update(clock: float) -> void:
	health_label.text = "HEALTH  %d / 3" % battle.player.health
	timer_label.text = "SURVIVE  %05.1f" % maxf(0,battle.end_time-clock)
	dialogue_label.visible = clock < 12.80 or (clock >= 64.00 and clock < 70.00)
	dialogue_label.text = battle.introductory_dialogue if clock < 12.80 else "You're stronger than you look. But how long can you survive?"
	saturate_label.text = "SURVIVAL() / OFFENSE DISABLED"

func show_phase(title: String) -> void:
	phase_label.text = title
	if is_instance_valid(phase_tween):
		phase_tween.kill()
	phase_label.modulate.a = 0
	phase_tween = create_tween()
	phase_tween.tween_property(phase_label,"modulate:a",1.0,0.2)
	phase_tween.tween_interval(1.2)
	phase_tween.tween_property(phase_label,"modulate:a",0.0,0.5)

func show_result(victory: bool) -> void:
	dialogue_label.hide()
	saturate_label.hide()
	result_label.text = "VICTORY()" if victory else "GAME OVER()"
	return_button.visible = victory
	end_screen.show()
	end_screen.modulate.a = 0
	create_tween().tween_property(end_screen,"modulate:a",1.0,0.4)
	if victory:
		return_button.grab_focus()
	else:
		return_button.get_parent().get_child(2).grab_focus()
