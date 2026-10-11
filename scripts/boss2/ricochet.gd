extends "res://scripts/boss2/projectile.gd"
var original_speed := 320.0
var bounce_count := 0
func _ready() -> void:
	super._ready()
	original_speed = speed
	add_to_group("boss2_ricochets")

func reflect(normal: Vector2) -> void:
	direction = direction.bounce(normal).normalized()
	speed = maxf(original_speed*0.5,speed*0.9)
	bounce_count += 1
	bounce_flash = 0.12
	get_parent().effects.burst(global_position,bullet_color.lightened(0.65),4,100,0.22)

func _physics_process(delta: float) -> void:
	if not dangerous:
		return
	move_reflecting(delta)
	bounce_flash = maxf(0,bounce_flash-delta)

func move_reflecting(delta: float) -> void:
	# Consume the remaining time after each impact, including corner reflections.
	# Tests can use a large step; real physics steps typically encounter <=1 wall.
	var bounds := get_viewport_rect().size
	var low := Vector2.ONE*body_radius
	var high := bounds-low
	global_position = global_position.clamp(low,high)
	var remaining := delta
	while remaining > 0.000001 and dangerous:
		var v := direction*speed
		var tx := INF
		var ty := INF
		if absf(v.x) > 0.00001:
			tx = maxf(0,((high.x if v.x > 0 else low.x)-global_position.x)/v.x)
		if absf(v.y) > 0.00001:
			ty = maxf(0,((high.y if v.y > 0 else low.y)-global_position.y)/v.y)
		var duration := minf(remaining,minf(tx,ty))
		var before := global_position
		global_position += v*duration
		test_segment(before,global_position,1-remaining/delta,1-(remaining-duration)/delta)
		remaining -= duration
		if tx <= duration+0.000001:
			reflect(Vector2.LEFT if v.x > 0 else Vector2.RIGHT)
		if ty <= duration+0.000001:
			reflect(Vector2.UP if v.y > 0 else Vector2.DOWN)
		# Nudge in the reflected direction to avoid zero-time repeated impacts.
		global_position = (global_position+direction*0.0001).clamp(low,high)
