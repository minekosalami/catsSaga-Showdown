extends CanvasLayer
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var battle: Node
var root: Control
var health_label: Label
var stage_label: Label
var timer_label: Label
var controls_label: Label
var ending_label: Label
var progress: ProgressBar
var phase_title: Control
var result: Control
var result_label: Label
var retry_button: Button
var return_button: Button
var practice_choice: OptionButton
var practice_button: Button
var effects_toggle: CheckButton
var menu_button: Button

func label(text: String, rect: Rect2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(node)
	return node

func _ready() -> void:
	battle = get_parent()
	root = Control.new()
	root.name = "BattleUI"
	root.size = Vector2(540,900)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/battle_hud_style.gd").theme()
	add_child(root)
	label("BLANKKITTEN",Rect2(20,24,500,34),25)
	label("Sequence()",Rect2(20,62,500,24),12)
	stage_label = label("Introduction",Rect2(20,365,500,32),17)
	var hud_back := ColorRect.new()
	hud_back.position = Vector2(20,795)
	hud_back.size = Vector2(500,94)
	hud_back.color = Color(0.025,0.03,0.043,0.94)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_back)
	health_label = label("HP  ● ● ● ● ●",Rect2(20,803,280,32),17)
	timer_label = label("00:00 / 02:25",Rect2(294,803,222,32),15)
	controls_label = label("ARROWS  Move",Rect2(20,853,500,25),13)
	progress = ProgressBar.new()
	progress.position = Vector2(28,843)
	progress.size = Vector2(484,3)
	progress.max_value = Cue.END
	progress.add_theme_font_size_override("font_size",1)
	preload("res://scripts/ui/battle_hud_style.gd").progress(progress,Color("#ECEAF5"))
	root.add_child(progress)
	progress.size.y = 3
	ending_label = label("",Rect2(48,480,444,180),18)
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_label.hide()
	phase_title = Control.new()
	phase_title.set_script(preload("res://scripts/ui/battle_phase_transition.gd"))
	root.add_child(phase_title)
	phase_title.label.offset_top = 386
	phase_title.label.offset_bottom = 426
	result = Control.new()
	result.name = "ResultScreen"
	result.set_script(preload("res://scripts/ui/cinematic_result.gd"))
	result.look = preload("res://resources/blankkitten/look.tres")
	result.size = Vector2(540,900)
	root.add_child(result)
	var stack := VBoxContainer.new()
	stack.position = Vector2(60,290)
	stack.size = Vector2(420,340)
	stack.add_theme_constant_override("separation",18)
	stack.theme = root.theme
	result.add_child(stack)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size",32)
	stack.add_child(result_label)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = ""
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",14)
	subtitle.custom_minimum_size.y = 46
	stack.add_child(subtitle)
	retry_button = action(stack,"RETRY()",func(): get_tree().current_scene.retry())
	return_button = action(stack,"RETURN()",func(): get_tree().current_scene.return_to_forest())
	menu_button = action(stack,"MAIN MENU",func(): get_tree().current_scene.main_menu())
	practice_choice = OptionButton.new()
	practice_choice.custom_minimum_size = Vector2(420,36)
	practice_choice.add_theme_font_size_override("font_size",13)
	stack.add_child(practice_choice)
	practice_button = action(stack,"PRACTICE()",func(): get_tree().current_scene.practice(practice_choice.get_selected_id()))
	result.hide()
	effects_toggle = CheckButton.new()
	effects_toggle.text = "REDUCED FX"
	effects_toggle.focus_mode = Control.FOCUS_NONE
	effects_toggle.position = Vector2(361,90)
	effects_toggle.size = Vector2(158,30)
	effects_toggle.add_theme_font_size_override("font_size",11)
	effects_toggle.set_pressed_no_signal(get_node("/root/VisualSettings").reduced)
	effects_toggle.toggled.connect(func(on):
		battle.reduced_effects = on
		Session.set_meta("blankkitten_reduced_effects",on)
		get_node("/root/VisualSettings").set_reduced(on))
	root.add_child(effects_toggle)
	get_node("/root/VisualSettings").changed.connect(_sync_visual_settings)
	_sync_visual_settings.call_deferred()

func _sync_visual_settings() -> void:
	var reduced: bool = get_node("/root/VisualSettings").reduced
	battle.reduced_effects = reduced
	Session.set_meta("blankkitten_reduced_effects",reduced)
	effects_toggle.set_pressed_no_signal(reduced)

func action(stack: VBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.set_script(preload("res://scripts/ui/sketch_button.gd"))
	button.text = text
	button.custom_minimum_size = Vector2(420,50)
	button.pressed.connect(callback)
	stack.add_child(button)
	return button

func update_clock(clock: float) -> void:
	var health: int = battle.player.health
	health_label.text = "HP %d / %d" % [health,battle.player.max_health]
	timer_label.text = "%02d:%02d / 02:25" % [int(clock)/60,int(clock)%60]
	stage_label.text = Cue.NAMES[battle.stage]
	var settings := get_node("/root/GameSettings")
	var horizontal: String=settings.binding_label("move_left").split(" / ")[0]+" / "+settings.binding_label("move_right").split(" / ")[0]
	var vertical: String=settings.binding_label("move_up").split(" / ")[0]+" / "+settings.binding_label("move_down").split(" / ")[0]
	controls_label.text = horizontal+"  Move    "+settings.binding_label("attack")+"  Jump (hold for height)" if Cue.GRAVITY[battle.stage] else horizontal+" / "+vertical+"  Move"
	progress.value = clock
	phase_title.flash_strength = .015 if battle.reduced_effects or get_node("/root/VisualSettings").reduced else .06
	phase_title.update_clock(clock)
	stage_label.visible = battle.practice_mode or battle.development_run or not phase_title.visible
	timer_label.modulate = Color(.83,.86,.92).lerp(Color.WHITE,(1-smoothstep(0,.13,fposmod(clock,Cue.MEASURE)))*.4)
	health_label.add_theme_color_override("font_color",Color("#FFF2F4") if health > 2 else Color("#FF6D93"))
	if battle.practice_mode: stage_label.text = "PRACTICE // "+Cue.NAMES[battle.stage]
	elif battle.development_run: stage_label.text = "PREVIEW // "+Cue.NAMES[battle.stage]
	ending_label.visible = battle.stage == 7 and not battle.cue_sheet.ending_lines.is_empty()
	if ending_label.visible:
		var index := mini(battle.cue_sheet.ending_lines.size()-1,int((clock-130.28)/(Cue.END-130.28)*battle.cue_sheet.ending_lines.size()))
		ending_label.text = battle.cue_sheet.ending_lines[index]

func stage_changed(stage: int, clock: float) -> void:
	var titles := {1:"FALLING PILLARS",2:"BOUNCING FIREBALL",4:"LASERS!",5:"JUMPING BEAMS",6:"SHOWDOWN()"}
	if titles.has(stage):
		phase_title.present(titles[stage],Color("#FF9BAE") if stage in [1,6] else Color("#E4DBFF"),clock,stage == 6)
		# Keep the announcement above every possible arena; it cannot hide a lane.
		phase_title.label.offset_top = 386
		phase_title.label.offset_bottom = 426

func show_result(won: bool, reason := "") -> void:
	result_label.text = "VICTORY()" if won else "GAME OVER()"
	retry_button.text="RETRY()" if won else "RETURN TO CHECKPOINT"
	result.get_child(0).get_node("Subtitle").text = "" if won or reason.is_empty() else reason
	return_button.visible = won
	practice_choice.clear()
	var seen: Dictionary = Session.get_meta("blankkitten_seen_stages",{})
	for index in [1,2,4,5,6]:
		if seen.has(index): practice_choice.add_item(Cue.NAMES[index],index)
	practice_choice.visible = practice_choice.item_count > 0
	practice_button.visible = practice_choice.visible
	result.show()
	result.modulate.a = 0
	create_tween().tween_property(result,"modulate:a",1.0,0.3)
	(return_button if won else retry_button).grab_focus()
