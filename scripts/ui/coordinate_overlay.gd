extends Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -290
	offset_top = -36
	offset_right = -16
	offset_bottom = -12
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	add_theme_font_size_override("font_size",14)
	add_theme_color_override("font_color",Color.WHITE)
	add_theme_color_override("font_outline_color",Color.BLACK)
	add_theme_constant_override("outline_size",4)
	hide()

func _process(_delta: float) -> void:
	var world: Node = Session.developer_cheats.context().world
	visible = Session.show_coordinates and world != null and not Session.busy and not world.dialogue.active and not world.map_modal_open()
	if visible:
		var point: Vector2 = world.player.global_position
		text = "X: %.1f | Y: %.1f" % [point.x,point.y]
