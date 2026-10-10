
extends Control

const SketchTheme = preload("res://scripts/ui/sketch_theme.gd")
const SketchButton = preload("res://scripts/ui/sketch_button.gd")
const SketchEmblem = preload("res://scripts/ui/sketch_emblem.gd")
const SketchBackground = preload("res://scripts/ui/sketch_background.gd")

var transitioning: bool = false
var options_dialog: AcceptDialog

var menu_container: VBoxContainer
var title_label: Label
var subtitle_label: Label


func _ready() -> void:
	theme = SketchTheme.create()
	_build_menu()
	menu_container.modulate.a = 0.0
	create_tween().tween_property(menu_container, "modulate:a", 1.0, 0.35)
	menu_container.get_node("StartButton").grab_focus()


func _build_menu() -> void:
	# Full-screen background.
	var background := Control.new()
	background.set_script(SketchBackground)
	background.name = "Background"
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
	menu_container.custom_minimum_size = Vector2(400, 0)
	menu_container.add_theme_constant_override("separation", 12)
	center.add_child(menu_container)

	var emblem := Control.new()
	emblem.name = "Emblem"
	emblem.set_script(SketchEmblem)
	emblem.custom_minimum_size.y = 200
	menu_container.add_child(emblem)

	# Game title.
	title_label = Label.new()
	title_label.text = "catsSaga()"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_font_override("font", SketchTheme.TITLE_FONT)
	title_label.add_theme_color_override("font_color", SketchTheme.INK)
	title_label.rotation = -0.012
	title_label.add_theme_color_override("font_shadow_color", Color("#b9b3a9"))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	menu_container.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "A STRANGE LITTLE ADVENTURE"
	subtitle_label.add_theme_color_override("font_color", Color("#5b5a58"))
	subtitle_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 12)
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
	version_label.text = "Z / SHOOT    X / SATURATE\nWASD / MOVE    SHIFT / FOCUS"
	version_label.add_theme_color_override("font_color", Color("#6e6b66"))
	version_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	menu_container.add_child(version_label)


func _add_button(button_text: String, action: Callable) -> void:
	var button := Button.new()
	button.set_script(SketchButton)
	button.text = button_text
	button.name = {"START GAME": "StartButton", "OPTIONS": "OptionsButton", "QUIT": "QuitButton"}[button_text]
	button.custom_minimum_size = Vector2(360, 62)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	menu_container.add_child(button)


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
		options_dialog.dialog_text = "Options menu coming soon.\n\nMove · WASD / arrows\nPrecision · Shift   Shoot · Z\nSATURATE · X (once per run)"
		options_dialog.theme = theme
		options_dialog.add_theme_color_override("font_color", SketchTheme.INK)
		add_child(options_dialog)
	options_dialog.popup_centered(Vector2i(360, 230))


func _quit_game() -> void:
	get_tree().quit()
