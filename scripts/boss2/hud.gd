extends CanvasLayer
const HUDStyle = preload("res://scripts/ui/battle_hud_style.gd")
const Transition = preload("res://scripts/ui/battle_phase_transition.gd")
@export_range(0.0,0.18,0.01) var phase_flash_strength := 0.08
@export_range(0.0,1.0,0.05) var phase_border_strength := 0.6
var phase_transition: Control
var current_phase_label: Label
var song_progress: ProgressBar
var health_card: PanelContainer
var top_margin: MarginContainer
var last_health := -1
var health_tween: Tween

var health_label: Label
var timer_label: Label
var phase_label: Label
var dialogue_label: Label
var saturate_label: Label
var end_screen: Control
var result_label: Label
var return_button: Button
var battle: Node

func _ready() -> void:
	battle = get_parent()
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = HUDStyle.theme()
	var margin := MarginContainer.new()
	top_margin = margin
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left","right","top"]:
		margin.add_theme_constant_override("margin_"+side,12)
	var panel := PanelContainer.new()
	health_card = panel
	margin.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",2)
	panel.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	stack.add_child(row)
	health_label = Label.new()
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_label.add_theme_font_size_override("font_size",16)
	row.add_child(health_label)
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size",18)
	row.add_child(timer_label)
	var phase_row := HBoxContainer.new()
	stack.add_child(phase_row)
	current_phase_label = Label.new()
	current_phase_label.name = "CurrentPhase"
	current_phase_label.add_theme_font_size_override("font_size",10)
	current_phase_label.add_theme_color_override("font_color",HUDStyle.BLUE)
	current_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_row.add_child(current_phase_label)
	var caption := Label.new()
	caption.text = "SONG / SURVIVAL"
	caption.add_theme_font_size_override("font_size",10)
	caption.add_theme_color_override("font_color",Color("#999890"))
	phase_row.add_child(caption)
	song_progress = ProgressBar.new()
	song_progress.name = "SongProgress"
	song_progress.custom_minimum_size.y = 5
	song_progress.max_value = 140.80
	song_progress.step = 0.001
	HUDStyle.progress(song_progress)
	stack.add_child(song_progress)
	_ignore_pointer(root)
	phase_transition = Control.new()
	phase_transition.set_script(Transition)
	root.add_child(phase_transition)
	phase_label = phase_transition.label
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
	top_margin.modulate.a = 0
	create_tween().tween_property(top_margin,"modulate:a",1.0,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func update(clock: float) -> void:
	var health: int = battle.player.health
	health_label.text = "● ".repeat(health) + "○ ".repeat(maxi(0,3-health)) + " %d / 3" % health
	health_label.modulate = Color("#E498BC") if health <= 1 else Color.WHITE
	if last_health >= 0 and health < last_health:
		if is_instance_valid(health_tween):
			health_tween.kill()
		health_card.modulate = Color("#E498BC")
		health_tween = create_tween()
		health_tween.tween_property(health_card,"modulate",Color.WHITE,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	last_health = health
	var remaining := maxf(0,battle.end_time-clock)
	timer_label.text = "%02d:%05.2f" % [int(remaining)/60,fmod(remaining,60)]
	song_progress.max_value = battle.end_time
	song_progress.value = clampf(clock,0,battle.end_time)
	phase_transition.update_clock(clock)
	dialogue_label.visible = clock < 12.80 or (clock >= 64.00 and clock < 70.00)
	dialogue_label.text = battle.introductory_dialogue if clock < 12.80 else "You're stronger than you look. But how long can you survive?"
	saturate_label.text = "SURVIVAL() / OFFENSE DISABLED"

func show_phase(title: String) -> void:
	current_phase_label.text = title
	phase_transition.flash_strength = phase_flash_strength
	phase_transition.border_strength = phase_border_strength
	var tint := Color("#B6EAF2") if title in ["Intermission()","Finale()"] else HUDStyle.BLUE
	phase_transition.present(title,tint,battle.timeline.clock,title == "Convergence()")
	if title != "Introduction()":
		battle.shake_time = maxf(battle.shake_time,0.16)
		battle.shake_strength = maxf(battle.shake_strength,1.5)

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)

func show_result(victory: bool) -> void:
	phase_transition.hide()
	create_tween().tween_property(top_margin,"modulate:a",0.0,0.2)
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
