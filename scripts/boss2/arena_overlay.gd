extends Control
var battle: Node
var warning_label: Label
var warning_clock := -1.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warning_label = Label.new()
	add_child(warning_label)
	warning_label.text = "LASERS!"
	warning_label.add_theme_font_size_override("font_size",102)
	warning_label.add_theme_color_override("font_color",Color("#FF2347"))
	warning_label.add_theme_color_override("font_outline_color",Color("#240510"))
	warning_label.add_theme_constant_override("outline_size",4)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.position = Vector2(0,375)
	warning_label.size = Vector2(540,140)
	warning_label.pivot_offset = Vector2(270,70)
	warning_label.hide()
func update_clock(clock: float) -> void:
	warning_clock = snappedf(clock-70.40,0.000001)
	warning_label.visible = warning_clock >= 0 and warning_clock < 0.80-0.000000001
	if warning_label.visible:
		var amount := lerpf(0.45,1.09,smoothstep(0,0.13,warning_clock)) if warning_clock < 0.13 else lerpf(1.09,1.0,smoothstep(0.13,0.29,warning_clock))
		warning_label.scale = Vector2.ONE*amount
		warning_label.modulate.a = 1-smoothstep(0.62,0.8,warning_clock)
	queue_redraw()
func _draw() -> void:
	if battle == null:
		return
	var phase: int = battle.timeline.phase
	var clock: float = battle.timeline.clock
	var tint := Color("#749BAD")
	var opacity := 0.32
	if phase == 3:
		tint = Color("#36E1FF")
		opacity = 0.75
	elif phase == 4:
		tint = Color("#FF2347")
		opacity = 0.4+sin(clock*TAU/1.6)*0.08
	draw_rect(Rect2(2,2,536,896),Color(tint,opacity*0.1),false,4)
	draw_rect(Rect2(2,2,536,896),Color(tint,opacity),false,1)
	if warning_clock >= 0 and warning_clock < 0.16:
		draw_rect(Rect2(0,0,540,900),Color(1,0.05,0.15,(1-warning_clock/0.16)*0.2))
