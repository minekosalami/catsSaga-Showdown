extends Control

# One reusable presentation layer, sampled from each fight's authoritative clock.
@export_range(0.0,0.18,0.01) var flash_strength := 0.08
@export_range(0.0,1.0,0.05) var border_strength := 0.6
var label: Label
var cue_time := -10.0
var clock := 0.0
var accent := Color("#81D8ED")
var dramatic := false
var duration := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.name = "PhaseAnnouncement"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 24
	label.offset_right = -24
	label.offset_top = 230
	label.offset_bottom = 270
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",4)
	label.hide()

func present(title: String, tint: Color, playback: float, emphasis: bool = false) -> void:
	cue_time = playback
	accent = tint
	dramatic = emphasis
	duration = 1.1 if emphasis else 0.85
	label.text = title
	label.add_theme_font_size_override("font_size",32 if emphasis else 24)
	label.add_theme_color_override("font_color",tint.lightened(0.25))
	label.show()
	update_clock(playback)

func update_clock(playback: float) -> void:
	clock = playback
	var age := maxf(0,clock-cue_time)
	var fade_in := smoothstep(0.0,0.12,age)
	var fade_out := 1-smoothstep(duration-0.3,duration,age)
	label.modulate.a = fade_in * fade_out * 0.92
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * (1 + 0.045 * (1-smoothstep(0.0,0.3,age)))
	if age >= duration:
		label.hide()
	queue_redraw()

func _draw() -> void:
	var age := clock-cue_time
	if age < 0 or age > duration:
		return
	var energy := 1-smoothstep(0.0,duration,age)
	if label.text != "Introduction()":
		var flash := (1-smoothstep(0.0,0.12,age)) * flash_strength
		draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,flash))
	var tint := Color(accent,energy * border_strength * 0.65)
	var inset := 4 + 5 * (1-energy)
	draw_rect(Rect2(Vector2.ONE * inset,size-Vector2.ONE * inset*2),tint,false,1.5)
	# Short corner brackets carry the transition without opaque arena coverage.
	for corner in [Vector2(8,8),Vector2(size.x-8,8),Vector2(8,size.y-8),size-Vector2(8,8)]:
		var direction := Vector2(1 if corner.x < size.x/2 else -1,1 if corner.y < size.y/2 else -1)
		draw_line(corner,corner+Vector2(direction.x*(18+18*energy),0),tint,2,true)
		draw_line(corner,corner+Vector2(0,direction.y*(18+18*energy)),tint,2,true)
