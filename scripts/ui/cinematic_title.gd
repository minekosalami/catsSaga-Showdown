extends Control
const BOLD = preload("res://assets/ui/fonts/DejaVuSansMono-Bold.ttf")
var look: Resource
var label: Label
var shimmer_material: ShaderMaterial
var clock := 0.0
var duration := 1.75
var opacity := 0.0
var energy := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.name = "ShowdownTitle"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",BOLD)
	label.add_theme_font_size_override("font_size",29)
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_color_override("font_outline_color",Color("#070B13"))
	shimmer_material = ShaderMaterial.new()
	shimmer_material.shader = preload("res://shaders/cinematic_title.gdshader")
	shimmer_material.set_shader_parameter("accent",look.accent)
	label.material = shimmer_material
	add_child(label)
	label.position = Vector2(20,422)
	label.size = Vector2(500,52)
	label.pivot_offset = Vector2(250,26)
	update_clock(0)

func update_clock(playback: float) -> void:
	clock = playback
	if look == null or label == null:
		return
	label.text = "Showdown: " + look.boss_name
	var entrance := 1-pow(1-clampf(clock/0.35,0,1),3)
	var exit := pow(clampf((clock-1.15)/0.6,0,1),3)
	opacity = smoothstep(0,0.15,clock)*(1-exit)
	energy = opacity*(1-smoothstep(1.1,1.6,clock))
	label.position.y = 422+18*(1-entrance)-12*exit
	label.scale = Vector2.ONE*(1.0+0.15*(1-entrance))
	var shimmer := maxf(0,1-absf(clock-0.7)/0.18)*0.18
	label.modulate = Color(1+shimmer,1+shimmer,1+shimmer,opacity)
	shimmer_material.set_shader_parameter("sweep",(clock-0.35)/0.8 if clock >= 0.35 and clock <= 1.15 else -1.0)
	visible = clock < duration
	queue_redraw()

func _draw() -> void:
	if look == null:
		return
	var center := Vector2(270,450)
	# Controlled glow behind the title; there is no opaque title card.
	for i in range(3):
		draw_line(center+Vector2(-145-i*9,30),center+Vector2(145+i*9,30),Color(look.accent,energy*0.018),8+i*6,true)
	var length := 154*smoothstep(0.12,0.35,clock)*(1-smoothstep(1.15,1.75,clock))
	draw_line(center+Vector2(-length,33),center+Vector2(length,33),Color(look.accent,energy*0.75),1.5,true)
	for i in range(6):
		var angle := i*TAU/6
		var p := center+Vector2.RIGHT.rotated(angle)*Vector2(150+clock*15,45+clock*8)
		draw_line(p,p+Vector2(0,3),Color(look.accent,energy*0.45),1,true)
