
extends Control

var menu_container: VBoxContainer
var title_label: Label
var subtitle_label: Label


func _ready() -> void:
	_build_menu()


func _build_menu() -> void:
	# Full-screen background.
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("#10091F")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Center the menu on the screen.
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	menu_container = VBoxContainer.new()
	menu_container.name = "MenuContainer"
	menu_container.custom_minimum_size = Vector2(360, 0)
	menu_container.add_theme_constant_override("separation", 18)
	center.add_child(menu_container)

	# Game title.
	title_label = Label.new()
	title_label.text = "catsSaga()"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	menu_container.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "A strange little adventure"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	menu_container.add_child(subtitle_label)

	# Space between title and buttons.
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	menu_container.add_child(spacer)

	# Menu buttons.
	_add_button("START GAME", _start_game)
	_add_button("OPTIONS", _open_options)
	_add_button("QUIT", _quit_game)

	# Version text.
	var version_label := Label.new()
	version_label.text = "catsSaga()"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	menu_container.add_child(version_label)


func _add_button(button_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(320, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	menu_container.add_child(button)


func _start_game() -> void:
	var result := get_tree().change_scene_to_file("res://scenes/main.tscn")

	if result != OK:
		push_error("Could not load main.tscn. Check the scene path.")


func _open_options() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Options"
	dialog.dialog_text = "Options menu coming soon."
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.popup_centered()


func _quit_game() -> void:
	get_tree().quit()
