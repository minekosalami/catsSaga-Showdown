extends AcceptDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Options"
	theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var hint := Label.new()
	hint.text = "F11 toggles fullscreen at any time."
	content.add_child(hint)
	var fullscreen := CheckButton.new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.text = "Fullscreen"
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	content.add_child(fullscreen)

func open() -> void:
	var toggle := find_child("FullscreenToggle", true, false) as CheckButton
	toggle.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	popup_centered(Vector2i(360, 180))
