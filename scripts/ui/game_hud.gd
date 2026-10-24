extends CanvasLayer

const SketchTheme = preload("res://scripts/ui/sketch_theme.gd")
const HUDStyle = preload("res://scripts/ui/battle_hud_style.gd")
const Transition = preload("res://scripts/ui/battle_phase_transition.gd")
const SketchButton = preload("res://scripts/ui/sketch_button.gd")

var health_label: Label
var timer_label: Label
var saturate_label: Label
var music_phase_caption: Label
var boss_caption: Label
var boss_value: Label
var boss_bar: ProgressBar
var boss_panel: PanelContainer
var victory_screen: Control
var victory_retry: Button
var victory_menu: Button
var victory_continue: Button
var defeat_backdrop: Control
var end_screen: CenterContainer
var observed_boss: Node
var bar_tween: Tween
var health_card: PanelContainer
var last_health: int = -1
var health_tween: Tween
var entrance_flash: ColorRect
var entrance_tween: Tween
@export_range(0.0, 0.25, 0.01) var phase_flash_strength := 0.12
var phase_label: Label
var phase_transition: Control
var entrance_ui_tween: Tween

func _label(parent: Node, text: String, font_size: int, color: Color = SketchTheme.PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var look: Resource = get_parent().get_node("CinematicArena").look
	var root := Control.new()
	root.name = "HUD"
	root.theme = HUDStyle.theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.name = "TopMargin"
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	health_card = PanelContainer.new()
	health_card.name = "PlayerCard"
	stack.add_child(health_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	health_card.add_child(row)
	var health_column := VBoxContainer.new()
	health_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(health_column)
	_label(health_column, "PLAYER / HP", 10, SketchTheme.MUTED)
	health_label = get_node("HealthLabel")
	health_label.reparent(health_column)
	health_label.add_theme_font_size_override("font_size", 18)
	var time_column := VBoxContainer.new()
	row.add_child(time_column)
	_label(time_column, "ELAPSED", 10, SketchTheme.MUTED)
	timer_label = _label(time_column, "00:00", 20)
	timer_label.name = "TimeLabel"

	boss_panel = PanelContainer.new()
	boss_panel.name = "BossPanel"
	stack.add_child(boss_panel)
	var boss_stack := VBoxContainer.new()
	boss_stack.add_theme_constant_override("separation", 7)
	boss_panel.add_child(boss_stack)
	var boss_row := HBoxContainer.new()
	boss_stack.add_child(boss_row)
	boss_caption = _label(boss_row, look.boss_name.to_upper()+" / PHASE 1", 12,look.accent)
	boss_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_value = _label(boss_row, "", 11, SketchTheme.MUTED)
	boss_bar = ProgressBar.new()
	boss_bar.name = "BossHealthBar"
	boss_bar.custom_minimum_size.y = 12
	HUDStyle.progress(boss_bar,look.accent)
	boss_stack.add_child(boss_bar)
	boss_panel.hide()
	music_phase_caption = _label(boss_stack,"Introduction()",10,SketchTheme.MUTED)

	var ability_card := PanelContainer.new()
	ability_card.name = "AbilityCard"
	root.add_child(ability_card)
	ability_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ability_card.offset_left = 12
	ability_card.offset_right = -12
	ability_card.offset_top = -52
	ability_card.offset_bottom = -12
	saturate_label = _label(ability_card, "", 13)
	saturate_label.name = "SaturateLabel"
	saturate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	end_screen = CenterContainer.new()
	end_screen.name = "EndScreen"
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	end_screen.add_child(card)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 320
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)
	_label(content, "", 12, SketchTheme.ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var game_over: Label = get_node("GameOverLabel")
	game_over.reparent(content)
	game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over.add_theme_font_override("font", preload("res://assets/ui/fonts/DejaVuSansMono-Bold.ttf"))
	game_over.add_theme_font_size_override("font_size", 40)
	_label(content, "MY PET DEAD.", 12, SketchTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var retry: Button = get_node("RestartButton")
	retry.reparent(content)
	retry.set_script(SketchButton)
	retry._ready()
	retry.text = "RETURN TO CHECKPOINT"
	retry.custom_minimum_size.y = 52
	retry.add_theme_stylebox_override("normal", SketchTheme.box(SketchTheme.INK, SketchTheme.MUTED))
	_ignore_pointer(root)
	retry.mouse_filter = Control.MOUSE_FILTER_STOP
	var death_menu := Button.new()
	death_menu.text="MAIN MENU"
	death_menu.custom_minimum_size.y=48
	content.add_child(death_menu)
	death_menu.pressed.connect(func():get_tree().current_scene.main_menu())
	var defeat_background := Control.new()
	defeat_backdrop = defeat_background
	defeat_background.name = "DefeatBackdrop"
	defeat_background.set_script(preload("res://scripts/ui/cinematic_result.gd"))
	defeat_background.look = look
	root.add_child(defeat_background)
	root.move_child(defeat_background,root.get_children().find(end_screen))
	defeat_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_background.hide()
	end_screen.hide()
	entrance_flash = ColorRect.new()
	entrance_flash.name = "EntranceFlash"
	entrance_flash.color = Color.WHITE
	entrance_flash.modulate.a = 0.0
	entrance_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(entrance_flash)
	entrance_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_transition = Control.new()
	phase_transition.set_script(Transition)
	root.add_child(phase_transition)
	phase_label = phase_transition.label
	_build_victory(root)
	margin.modulate.a = 0.0
	entrance_ui_tween = create_tween()
	entrance_ui_tween.tween_property(margin,"modulate:a",1.0,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)

func _process(_delta: float) -> void:
	phase_transition.flash_strength = .015 if get_node("/root/VisualSettings").reduced or get_node("/root/GameSettings").values.flashing else phase_flash_strength
	var game := get_parent()
	var player: Node = game.get_node_or_null("Player")
	if player != null:
		health_label.text = "HP %d / %d" % [player.health,player.max_health]
		health_label.modulate = SketchTheme.ACCENT if player.health <= 1 else SketchTheme.PAPER
		if last_health != -1 and player.health < last_health:
			if is_instance_valid(health_tween):
				health_tween.kill()
			health_card.modulate = SketchTheme.ACCENT
			health_tween = create_tween()
			health_tween.tween_property(health_card, "modulate", Color.WHITE, 0.3)
		last_health = player.health
		var ability_state := "[ UNLIMITED ]" if player.unlimited_saturate else ("[ USED ]" if player.saturate_used else "[ READY ]")
		saturate_label.text = get_node("/root/GameSettings").binding_label("ability")+"  /  SATURATE     " + ability_state
		saturate_label.modulate = SketchTheme.MUTED if player.saturate_used and not player.unlimited_saturate else SketchTheme.ACCENT
	phase_transition.update_clock(game.elapsed_time)
	if phase_label.text == "Introduction()":
		phase_label.hide()
	var seconds := int(game.elapsed_time)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if is_instance_valid(game.boss) and game.boss != observed_boss:
		observed_boss = game.boss
		observed_boss.health_changed.connect(_boss_health_changed)
		observed_boss.defeated.connect(func(): boss_panel.hide())
		boss_bar.max_value = observed_boss.max_health
		boss_bar.value = observed_boss.health
		_boss_health_changed(observed_boss.health, observed_boss.max_health, observed_boss.phase)
		boss_panel.show()
		boss_panel.modulate.a = 0.0
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(boss_panel, "modulate:a", 1.0, 0.35)
	if not is_instance_valid(game.boss):
		boss_panel.hide()
	if game.game_over and not end_screen.visible:
		end_screen.find_child("GameOverLabel",true,false).text = "GAME OVER()"
		defeat_backdrop.show()
		var introduction := get_child(0).get_node_or_null("CinematicIntroduction")
		if introduction != null:
			introduction.hide()
		end_screen.show()
		end_screen.modulate.a = 0.0
		create_tween().tween_property(end_screen, "modulate:a", 1.0, 0.25)
		var retry := end_screen.find_child("RestartButton", true, false) as Button
		retry.grab_focus()

func _boss_health_changed(health: float, maximum: int, phase: int) -> void:
	boss_caption.text = get_parent().get_node("CinematicArena").look.boss_name.to_upper()+" / PHASE %d" % phase
	boss_value.text = "%d / %d" % [health, maximum]
	boss_bar.max_value = maximum
	if is_instance_valid(bar_tween):
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(boss_bar, "value", float(health), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func show_boss_entrance() -> void:
	# One short pulse, called only by the guarded boss spawn at the music drop.
	entrance_flash.modulate.a = .015 if get_node("/root/VisualSettings").reduced or get_node("/root/GameSettings").values.flashing else phase_flash_strength
	entrance_tween = create_tween()
	entrance_tween.tween_property(entrance_flash, "modulate:a", 0.0, 0.10)

func show_phase(title: String, color: Color, dramatic: bool = false) -> void:
	phase_transition.flash_strength = minf(phase_flash_strength,0.12)
	music_phase_caption.text = title
	phase_transition.present(title,color,get_parent().elapsed_time,dramatic)
	if title == "Introduction()":
		phase_transition.label.hide()

func show_impact_flash() -> void:
	if is_instance_valid(entrance_tween):
		entrance_tween.kill()
	entrance_flash.modulate.a = 0.0 if get_node("/root/GameSettings").values.flashing else minf(phase_flash_strength, 0.12)
	entrance_tween = create_tween()
	entrance_tween.tween_property(entrance_flash, "modulate:a", 0.0, 0.18)

func _build_victory(root: Control) -> void:
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	root.add_child(victory_screen)
	victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := Control.new()
	background.set_script(preload("res://scripts/ui/cinematic_result.gd"))
	background.look = get_parent().get_node("CinematicArena").look
	victory_screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	victory_screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 400
	content.add_theme_constant_override("separation", 24)
	center.add_child(content)
	_label(content, "// EXECUTION COMPLETE", 12, SketchTheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(content, "VICTORY()", 48)
	title.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono-Bold.ttf"))
	title.name = "VictoryTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(content, "Smoki defeated.", 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	content.add_child(spacer)
	for to_menu in [false, true]:
		var button := Button.new()
		button.set_script(SketchButton)
		button.text = "MAIN MENU" if to_menu else "RETRY"
		button.name = "MainMenuButton" if to_menu else "VictoryRetry"
		button.custom_minimum_size = Vector2(360, 56)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func(): get_parent().navigate_victory(to_menu))
		content.add_child(button)
		if to_menu:
			victory_menu = button
		else:
			victory_retry = button
	victory_continue = Button.new()
	victory_continue.set_script(SketchButton)
	victory_continue.text = "RETURN TO FOREST"
	victory_continue.custom_minimum_size = Vector2(360, 56)
	victory_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	victory_continue.pressed.connect(func():
		if not Session.busy:
			get_tree().current_scene.return_to_forest()
	)
	content.add_child(victory_continue)
	content.move_child(victory_continue, 4)
	victory_continue.visible = Session.encounter_active
	victory_screen.hide()

func show_victory() -> void:
	if victory_screen.visible:
		return
	boss_panel.hide()
	victory_screen.show()
	victory_screen.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(victory_screen, "modulate:a", 1.0, 0.35)
	if victory_continue.visible:
		victory_continue.grab_focus()
	else:
		victory_retry.grab_focus()
