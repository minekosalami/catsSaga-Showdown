extends Control

const SketchTheme = preload("res://scripts/ui/sketch_theme.gd")
const SketchButton = preload("res://scripts/ui/sketch_button.gd")
const SketchBackground = preload("res://scripts/ui/sketch_background.gd")

var transitioning: bool = false
var options_dialog: AcceptDialog
var menu_container: VBoxContainer
var title_label: Label
var info_container: VBoxContainer
var controls_panel: MarginContainer
var controls_grids: Array[GridContainer] = []
var info_content: Label

func _ready() -> void:
	theme = SketchTheme.create()
	_build_menu()
	menu_container.modulate.a = 0.0
	create_tween().tween_property(menu_container, "modulate:a", 1.0, 0.35)
	menu_container.get_node("StartButton").grab_focus()

func _build_menu() -> void:
	var background := Control.new()
	background.set_script(SketchBackground)
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	menu_container = VBoxContainer.new()
	menu_container.name = "Menu"
	menu_container.custom_minimum_size.x = 400
	menu_container.add_theme_constant_override("separation", 16)
	center.add_child(menu_container)
	title_label = Label.new()
	title_label.text = "catsSaga()"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	menu_container.add_child(title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 42
	menu_container.add_child(spacer)
	_button(menu_container, "START GAME", "StartButton", _start_game)
	_button(menu_container, "OPTIONS", "OptionsButton", _open_options)
	_button(menu_container, "INFO", "InfoButton", _show_info)
	_button(menu_container, "QUIT", "QuitButton", _quit_game)
	_build_info(center)

func _button(parent: Node, text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.set_script(SketchButton)
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(360, 56)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_info(center: CenterContainer) -> void:
	info_container = VBoxContainer.new()
	info_container.name = "Info"
	info_container.custom_minimum_size.x = 400
	info_container.add_theme_constant_override("separation", 16)
	center.add_child(info_container)
	var heading := Label.new()
	heading.text = "// INFO"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	info_container.add_child(heading)
	_button(info_container, "CONTROLS", "ControlsButton", _show_controls)
	_button(info_container, "CREDITS", "CreditsButton", _show_credits)
	info_content = Label.new()
	info_content.name = "InfoContent"
	info_content.custom_minimum_size = Vector2(400, 205)
	info_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_content.add_theme_font_size_override("font_size", 14)
	info_container.add_child(info_content)
	_build_controls()
	_button(info_container, "BACK", "BackButton", _back_to_menu)
	info_container.hide()

func _show_info() -> void:
	menu_container.hide()
	info_container.show()
	_show_controls()
	info_container.get_node("ControlsButton").grab_focus()
	info_container.modulate.a = 0.0
	create_tween().tween_property(info_container, "modulate:a", 1.0, 0.2)

func _show_controls() -> void:
	info_content.hide()
	controls_panel.show()

func _show_credits() -> void:
	controls_panel.hide()
	info_content.show()
	info_content.add_theme_font_size_override("font_size", 20)
	info_content.text = "LLiosette — Creator"

func _back_to_menu() -> void:
	info_container.hide()
	menu_container.show()
	menu_container.get_node("InfoButton").grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if info_container.visible and event.is_action_pressed("ui_cancel"):
		_back_to_menu()
		get_viewport().set_input_as_handled()

func _start_game() -> void:
	if transitioning:
		return
	transitioning = true
	for child in menu_container.get_children():
		if child is Button:
			child.disabled = true
	var fade := create_tween()
	fade.tween_property(menu_container, "modulate:a", 0.0, 0.2)
	await fade.finished
	var result := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if result != OK:
		push_error("Could not load main.tscn. Check the scene path.")
		transitioning = false
		menu_container.modulate.a = 1.0
		for child in menu_container.get_children():
			if child is Button:
				child.disabled = false

func _open_options() -> void:
	if not is_instance_valid(options_dialog):
		options_dialog = AcceptDialog.new()
		options_dialog.title = "Options"
		options_dialog.dialog_text = "Options coming soon."
		options_dialog.theme = theme
		add_child(options_dialog)
	options_dialog.popup_centered(Vector2i(360, 180))

func _quit_game() -> void:
	get_tree().quit()

func _build_controls() -> void:
	controls_panel = MarginContainer.new()
	controls_panel.name = "ControlsContent"
	for side in ["left", "right", "top", "bottom"]:
		controls_panel.add_theme_constant_override("margin_" + side, 20)
	info_container.add_child(controls_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	controls_panel.add_child(content)
	for section in [
		["// MOVEMENT", [["WASD / ARROWS", "Move"], ["SHIFT", "Focus movement"]]],
		["// ATTACK", [["Z", "Shoot"], ["X", "SATURATE"]]]
	]:
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_size_override("font_size", 12)
		heading.add_theme_color_override("font_color", SketchTheme.MUTED)
		content.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 18)
		content.add_child(grid)
		controls_grids.append(grid)
		for binding in section[1]:
			for column in range(2):
				var label := Label.new()
				label.text = binding[column]
				label.custom_minimum_size = Vector2(140 if column == 0 else 160, 32)
				label.add_theme_font_size_override("font_size", 15)
				grid.add_child(label)
	var note := Label.new()
	note.text = "SATURATE: once per run."
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", SketchTheme.MUTED)
	content.add_child(note)
