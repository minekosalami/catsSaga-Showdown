extends Sprite2D

@export_range(30.0,300.0,1.0) var beats_per_minute := 150.0
@export_range(1,12,1) var beats_per_measure := 4
@export var downbeat_offset := 0.0
@export_range(0.0,0.1,0.005) var pulse_amount := 0.06
@export_range(0.1,0.6,0.01) var pulse_duration := 0.32
@export_range(0.0,16.0,0.5) var float_amplitude := 8.0
@export_range(1.0,8.0,0.1) var float_cycle := 3.2
var rest_scale: Vector2
var rest_offset: Vector2
var measure_phase := 0.0
var float_pixels := 0.0

func _ready() -> void:
	rest_scale = scale
	rest_offset = offset

func _process(_delta: float) -> void:
	apply_clock(get_parent().clock)

func apply_clock(playback: float) -> void:
	var measure := 60.0 / beats_per_minute * beats_per_measure
	var aligned := playback-downbeat_offset
	measure_phase = fposmod(aligned,measure)
	var rise := minf(0.06,pulse_duration*0.25)
	var envelope := 0.0
	if aligned >= 0 and measure_phase < pulse_duration:
		if measure_phase < rise:
			envelope = smoothstep(0.0,rise,measure_phase)
		else:
			envelope = 1-smoothstep(rise,pulse_duration,measure_phase)
	scale = rest_scale * (1+pulse_amount * envelope)
	float_pixels = sin(playback * TAU / float_cycle) * float_amplitude
	# offset moves drawing only; position stays the stable formation/spawn origin.
	offset = rest_offset + Vector2(0,float_pixels/maxf(0.001,scale.y))
