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

var stamina_bar: ProgressBar
var stamina_caption: Label
var arena_overlay: Control
var health_label: Label
var timer_label: Label
var phase_label: Label
var dialogue_label: Label
var end_screen: Control
var result_label: Label
var return_button: Button
var battle: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle = get_parent()
	var look: Resource = battle.get_node("CinematicArena").look
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
	var headings := HBoxContainer.new()
	stack.add_child(headings)
	var hp_heading := Label.new()
	hp_heading.text = "PLAYER / HP"
	hp_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_heading.add_theme_font_size_override("font_size",10)
	hp_heading.add_theme_color_override("font_color",Color("#999890"))
	headings.add_child(hp_heading)
	var time_heading := Label.new()
	time_heading.text = "REMAINING"
	time_heading.add_theme_font_size_override("font_size",10)
	time_heading.add_theme_color_override("font_color",Color("#999890"))
	headings.add_child(time_heading)
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
	current_phase_label.add_theme_font_size_override("font_size",12)
	current_phase_label.add_theme_color_override("font_color",HUDStyle.BLUE)
	current_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_row.add_child(current_phase_label)
	var caption := Label.new()
	caption.text = look.boss_name.to_upper()+" / SURVIVAL"
	caption.add_theme_font_size_override("font_size",10)
	caption.add_theme_color_override("font_color",look.accent)
	phase_row.add_child(caption)
	song_progress = ProgressBar.new()
	song_progress.name = "SongProgress"
	song_progress.custom_minimum_size.y = 3
	song_progress.max_value = 140.80
	song_progress.step = 0.001
	HUDStyle.progress(song_progress,look.accent)
	stack.add_child(song_progress)
	var sprint_row := HBoxContainer.new()
	stack.add_child(sprint_row)
	stamina_caption = Label.new()
	stamina_caption.text = "SPRINT() / X"
	stamina_caption.add_theme_font_size_override("font_size",10)
	stamina_caption.custom_minimum_size.x = 120
	sprint_row.add_child(stamina_caption)
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "SprintStamina"
	stamina_bar.max_value = 1.0
	stamina_bar.step = 0.001
	stamina_bar.value = 1.0
	stamina_bar.custom_minimum_size.y = 6
	stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HUDStyle.progress(stamina_bar,Color.WHITE)
	sprint_row.add_child(stamina_bar)
	dialogue_label = Label.new()
	dialogue_label.custom_minimum_size = Vector2(460,0)
	stack.add_child(dialogue_label)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size",11)
	dialogue_label.add_theme_color_override("font_color",Color("#CBE7EB"))
	phase_transition = Control.new()
	phase_transition.set_script(Transition)
	root.add_child(phase_transition)
	phase_label = phase_transition.label
	arena_overlay = Control.new()
	arena_overlay.set_script(preload("res://scripts/boss2/arena_overlay.gd"))
	root.add_child(arena_overlay)
	arena_overlay.battle = battle
	_ignore_pointer(root)
	end_screen = Control.new()
	end_screen.set_script(preload("res://scripts/ui/cinematic_result.gd"))
	end_screen.look = look
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	end_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",20)
	center.add_child(content)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono-Bold.ttf"))
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
			button.name="RetryButton"
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
	# Existing cross warning remains the sole warning typography.
	if battle.timeline.phase in [0,4] or clock-phase_transition.cue_time > phase_transition.duration:
		phase_label.hide()
	arena_overlay.update_clock(clock)
	stamina_bar.value = battle.player.stamina
	stamina_bar.modulate = Color("#F48BB6") if battle.player.stamina < 0.2 else Color.WHITE
	var ability_key: String=get_node("/root/GameSettings").binding_label("ability")
	stamina_caption.text = "SPRINT() / RELEASE "+ability_key if battle.player.exhausted_until_release else ("SPRINT() / EMPTY" if battle.player.stamina <= 0.001 else "SPRINT() / "+ability_key)
	var authored_intro: bool = not battle.introductory_dialogue.begins_with("[Automatic introductory dialogue placeholder")
	dialogue_label.visible = (clock < 12.80 and authored_intro) or (clock >= 64.00 and clock < 70.00) or (clock >= 70.40 and clock < 71.20)
	dialogue_label.text = battle.introductory_dialogue if clock < 12.80 else ("NOW DIE!" if clock >= 70.40 else "You're stronger than you look. But how long can you survive?")

func show_phase(title: String) -> void:
	current_phase_label.text = title
	phase_transition.flash_strength = .015 if get_node("/root/VisualSettings").reduced or get_node("/root/GameSettings").values.flashing else phase_flash_strength
	phase_transition.border_strength = phase_border_strength
	var tint := Color("#B6EAF2") if title in ["RICOCHET()","Finale()"] else HUDStyle.BLUE
	if title == "CrossLaser()":
		tint = Color("#FF4766")
	phase_transition.present("NOW DIE!" if title == "CrossLaser()" else ("Showdown()" if title == "Finale()" else title),tint,battle.timeline.clock,title == "Finale()")
	if title != "Introduction()":
		battle.shake_time = maxf(battle.shake_time,0.16)
		battle.shake_strength = maxf(battle.shake_strength,4.0 if title == "CrossLaser()" else 1.5)

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)

func show_result(victory: bool) -> void:
	var introduction := get_child(0).get_node_or_null("CinematicIntroduction")
	if introduction != null:
		introduction.hide()
	phase_transition.hide()
	create_tween().tween_property(top_margin,"modulate:a",0.0,0.2)
	dialogue_label.hide()
	arena_overlay.hide()
	result_label.text = "VICTORY()" if victory else "GAME OVER()"
	end_screen.find_child("RetryButton",true,false).text="RETRY" if victory else "LOAD LAST SAVE"
	result_label.add_theme_font_size_override("font_size",48 if victory else 40)
	return_button.visible = victory
	end_screen.show()
	end_screen.modulate.a = 0
	create_tween().tween_property(end_screen,"modulate:a",1.0,0.4)
	if victory:
		return_button.grab_focus()
	else:
		return_button.get_parent().get_child(2).grab_focus()
