extends Camera2D
## Exploration only. Session freezes this entire branch during the protected entry.
@export_range(0.0,64.0,1.0) var look_ahead := 42.0
@export_range(4.0,20.0,.5) var follow_response := 11.0
var followed := Vector2.ZERO
var lead := Vector2.ZERO
func _ready() -> void:
	set_process(true)
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	process_priority = 50
	followed = get_parent().global_position
	zoom=Vector2.ONE*get_node("/root/GameSettings").values.zoom
func _process(delta: float) -> void:
	if Session.busy or get_parent().movement_locked:return
	zoom=Vector2.ONE*get_node("/root/GameSettings").values.zoom
	var actor := get_parent()
	var target: Vector2 = actor.velocity/actor.speed*look_ahead
	target = target.limit_length(look_ahead)
	lead = lead.lerp(target,1-exp(-delta*7))
	var wanted: Vector2 = actor.visual_position()+lead
	if followed.distance_to(wanted)>500:followed = wanted
	followed = followed.lerp(wanted,1-exp(-delta*follow_response))
	# A world-pixel grid becomes uneven screen jumps at fractional zoom/stretch.
	# Track the same interpolated presentation as the cat, without quantization.
	global_position = followed
	force_update_scroll()
