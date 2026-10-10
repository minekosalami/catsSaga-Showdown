extends CanvasLayer

const SketchTheme = preload("res://scripts/ui/sketch_theme.gd")
const SketchButton = preload("res://scripts/ui/sketch_button.gd")

var health_label: Label
var timer_label: Label
var saturate_label: Label
var boss_caption: Label
var boss_bar: ProgressBar
var boss_panel: VBoxContainer
var end_screen: CenterContainer
var observed_boss: Node
var bar_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "HUD"
	root.theme = SketchTheme.create()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.name = "TopMargin"
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	health_label = get_node("HealthLabel")
	health_label.reparent(row)
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_label.add_theme_font_size_override("font_size", 18)
	timer_label = Label.new()
	timer_label.name = "TimeLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 18)
	row.add_child(timer_label)

	boss_panel = VBoxContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.add_theme_constant_override("separation", 3)
	stack.add_child(boss_panel)
	boss_caption = Label.new()
	boss_caption.add_theme_font_size_override("font_size", 11)
	boss_panel.add_child(boss_caption)
	boss_bar = ProgressBar.new()
	boss_bar.name = "BossHealthBar"
	boss_bar.custom_minimum_size.y = 5
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(boss_bar)
	boss_panel.hide()

	saturate_label = Label.new()
	saturate_label.name = "SaturateLabel"
	root.add_child(saturate_label)
	saturate_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	saturate_label.offset_left = -200
	saturate_label.offset_top = -38
	saturate_label.offset_right = -18
	saturate_label.offset_bottom = -14
	saturate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saturate_label.add_theme_font_size_override("font_size", 13)

	end_screen = CenterContainer.new()
	end_screen.name = "EndScreen"
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	end_screen.add_child(card)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 300
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)
	var game_over: Label = get_node("GameOverLabel")
	game_over.reparent(content)
	game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over.add_theme_font_size_override("font_size", 30)
	var note := Label.new()
	note.text = "MY PET DEAD."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = SketchTheme.MUTED
	content.add_child(note)
	var retry: Button = get_node("RestartButton")
	retry.reparent(content)
	retry.set_script(SketchButton)
	# set_script on an already-ready node does not run its new _ready callback.
	retry._ready()
	retry.text = "TRY AGAIN"
	retry.custom_minimum_size.y = 52
	_ignore_pointer(root)
	retry.mouse_filter = Control.MOUSE_FILTER_STOP
	end_screen.hide()

func _ignore_pointer(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)

func _process(_delta: float) -> void:
	var game := get_parent()
	var player: Node = game.get_node_or_null("Player")
	if player != null:
		health_label.text = "HP  " + "● ".repeat(player.health) + "○ ".repeat(maxi(0, 3 - player.health))
		health_label.modulate = SketchTheme.ACCENT if player.health == 1 else SketchTheme.PAPER
		saturate_label.text = "X  /  SATURATE " + ("— USED" if player.saturate_used else "— READY")
		saturate_label.modulate = SketchTheme.MUTED if player.saturate_used else SketchTheme.ACCENT
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
	if not is_instance_valid(game.boss):
		boss_panel.hide()
	if game.game_over and not end_screen.visible:
		end_screen.show()
		end_screen.modulate.a = 0.0
		create_tween().tween_property(end_screen, "modulate:a", 1.0, 0.25)
		var retry := end_screen.find_child("RestartButton", true, false) as Button
		retry.grab_focus()

func _boss_health_changed(health: int, maximum: int, phase: int) -> void:
	boss_caption.text = "BART  /  PHASE %d" % phase
	boss_bar.max_value = maximum
	if is_instance_valid(bar_tween):
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(boss_bar, "value", float(health), 0.18)
