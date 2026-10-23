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
	var ambient := CheckButton.new()
	ambient.name = "AmbienceToggle"
	ambient.text = "Environmental ambience"
	ambient.set_pressed_no_signal(get_node("/root/Ambience").enabled)
	ambient.toggled.connect(get_node("/root/Ambience").set_enabled)
	content.add_child(ambient)
	var reduced := CheckButton.new()
	reduced.name = "ReducedEffectsToggle"
	reduced.text = "Reduced battle effects"
	reduced.set_pressed_no_signal(get_node("/root/VisualSettings").reduced)
	reduced.toggled.connect(get_node("/root/VisualSettings").set_reduced)
	content.add_child(reduced)
	var label := Label.new()
	label.text = "Background motion"
	content.add_child(label)
	var motion := HSlider.new()
	motion.name = "BackgroundMotion"
	motion.min_value = 0
	motion.max_value = 1
	motion.step = .05
	motion.value = get_node("/root/VisualSettings").motion
	motion.value_changed.connect(get_node("/root/VisualSettings").set_motion)
	content.add_child(motion)

func open() -> void:
	var toggle := find_child("FullscreenToggle", true, false) as CheckButton
	toggle.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	(find_child("AmbienceToggle",true,false) as CheckButton).set_pressed_no_signal(get_node("/root/Ambience").enabled)
	(find_child("ReducedEffectsToggle",true,false) as CheckButton).set_pressed_no_signal(get_node("/root/VisualSettings").reduced)
	(find_child("BackgroundMotion",true,false) as HSlider).set_value_no_signal(get_node("/root/VisualSettings").motion)
	popup_centered(Vector2i(410, 350))
