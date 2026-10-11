extends Node2D

# These controls affect scenery only, never actors or collision transforms.
@export_range(0.0, 1.0, 0.05) var effect_intensity := 0.45
@export_range(0.0, 1.0, 0.05) var shake_intensity := 0.6
@export var phase_particles_enabled := true
const CUES := [0.0, 6.85, 20.57, 34.28, 48.0, 61.71, 89.14, 116.0, 123.0]
const TITLES := ["Introduction()", "Arrival()", "RisingPressure()", "Refraction()", "BreathingRoom()", "FinalClimax()", "Showdown()", "FinalSequence()", "Ending()"]
const LEVELS := [0.03, 0.12, 0.25, 0.35, 0.18, 0.55, 0.80, 1.0, 0.0]
const COLORS := [Color("#99A7BB"), Color("#55E8FF"), Color("#A18CFF"), Color("#F68AC4"), Color("#819BC4"), Color("#FF596F"), Color("#F5B7FF"), Color("#FFE66D"), Color.WHITE]
var cue_index := -1
var clock := 0.0
var shader: ShaderMaterial
var background: Sprite2D
var background_origin: Vector2

func _ready() -> void:
	z_index = -8
	background = get_parent().get_node("Sprite2D")
	background_origin = background.position
	shader = ShaderMaterial.new()
	shader.shader = preload("res://shaders/battle_background.gdshader")
	background.material = shader

func update_clock(playback: float) -> void:
	clock = playback
	var active := 0
	for i in range(CUES.size()):
		if playback >= CUES[i]:
			active = i
	if cue_index != active:
		cue_index = active
		var hud: Node = get_parent().get_node("UI")
		hud.show_phase(TITLES[active], COLORS[active], active == 6)
		if active > 0 and active < 8:
			get_parent().shake_time = maxf(get_parent().shake_time, 0.16 if active != 6 else 0.25)
			get_parent().shake_strength = 3.0 if active != 6 else 5.0
			if phase_particles_enabled:
				preload("res://scripts/ui/battle_burst.gd").spawn(get_parent(), Vector2(270, 270), COLORS[active], 70 if active == 6 else 45)
	shader.set_shader_parameter("clock", clock)
	shader.set_shader_parameter("intensity", LEVELS[active] * effect_intensity)
	shader.set_shader_parameter("atmosphere", COLORS[active])
	queue_redraw()

func apply_shake(offset: Vector2) -> void:
	var visual_offset := offset.limit_length(3.0) * shake_intensity
	position = visual_offset
	background.position = background_origin + visual_offset

func _draw() -> void:
	if cue_index < 0:
		return
	var level: float = LEVELS[cue_index] * effect_intensity
	var tint := Color(COLORS[cue_index], (0.12 + 0.12 * sin(clock * 1.7)) * level)
	draw_rect(Rect2(4, 4, 532, 892), tint, false, 2)
	for i in range(6):
		var point := Vector2(270 + sin(clock * 0.35 + i) * 230, 180 + i * 110)
		var radius := 12.0 + sin(clock + i) * 4
		draw_arc(point, radius, PI/4 + clock * 0.1, PI*1.75 + clock * 0.1, 16, tint, 1)
