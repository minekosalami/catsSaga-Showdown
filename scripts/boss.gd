extends Area2D

signal health_changed(current_health: int, max_health: int, phase: int)
signal defeated
signal defeat_finished

@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemybullet.tscn")

var max_health: int = 180
var health: int = 180

# Health-based phases for the boss HUD.
var phase: int = 1
var move_direction: float = 1.0
var move_speed: float = 70.0
var horizontal_velocity: float = 0.0
var movement_time: float = 0.0
var entrance_tween: Tween
var sprite_resting_scale: Vector2

# This value is synchronized by main.gd with the music.
var elapsed: float = 0.0

var shoot_timer: float = 1.0
var attack_index: int = 0

var spiral_timer: float = 0.0
var spiral_remaining: int = 0
var spiral_angle: float = 0.0
var spiral_angle_step: float = 0.23
var spiral_double: bool = false

var defeated_already: bool = false
var attacks_stopped: bool = false

# Song timeline, in seconds.
const DROP_TIME: float = 6.85
const SECOND_INSTRUMENT_TIME: float = 20.57
const SHOWDOWN_TIME: float = 89.14
const CALM_TIME: float = 48.00
const FINAL_CLIMAX_TIME: float = 61.71
const SONG_END_TIME: float = 123.0

var song_section: int = 0


func _ready() -> void:
	sprite_resting_scale = $Sprite2D.scale
	add_to_group("enemies")
	health_changed.emit(health, max_health, phase)


func _process(delta: float) -> void:
	if defeated_already or attacks_stopped:
		return

	# main.gd supplies the current music playback position.
	if elapsed >= SONG_END_TIME:
		stop_attacking()
		return

	update_song_section()
	update_phase()
	move_boss(delta)

	# Continue an active spiral.
	if spiral_remaining > 0:
		spiral_timer -= delta

		if spiral_timer <= 0.0:
			fire_spiral_step()
			spiral_timer = get_spiral_interval()

	# Start another attack when the cooldown expires.
	shoot_timer -= delta

	if shoot_timer <= 0.0:
		attack()
		set_attack_cooldown()


func stop_attacking() -> void:
	if attacks_stopped:
		return

	attacks_stopped = true
	spiral_remaining = 0
	shoot_timer = 999999.0
	set_process(false)

	print("BART: FIGHT ENDED")


func play_entrance() -> void:
	# Animate only the artwork, keeping collision shapes and shot origins stable.
	var sprite: Sprite2D = $Sprite2D
	var resting_scale := sprite.scale
	var resting_position := sprite.position
	sprite.position.y += 28.0
	sprite.scale = resting_scale * Vector2(0.82, 1.18)
	entrance_tween = create_tween().set_parallel(true)
	entrance_tween.tween_property(sprite, "position", resting_position, 0.48).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	entrance_tween.tween_property(sprite, "scale", resting_scale, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func move_boss(delta: float) -> void:
	var screen_width: float = get_viewport_rect().size.x
	var sprite: Sprite2D = $Sprite2D
	# Fixed visual bounds exclude the temporary entrance squash/stretch.
	var half_width: float = sprite.texture.get_width() * sprite_resting_scale.x * 0.5
	var min_x := 8.0 - sprite.position.x + half_width
	var max_x := screen_width - 8.0 - sprite.position.x - half_width
	movement_time += delta
	# Reverse the target early; actual velocity decelerates through zero smoothly.
	if position.x >= max_x - 16.0:
		move_direction = -1.0
	elif position.x <= min_x + 16.0:
		move_direction = 1.0
	var distance := max_x - position.x if move_direction > 0.0 else position.x - min_x
	var ease_speed := smoothstep(0.0, 60.0, maxf(distance, 0.0))
	var drift := 0.9 + 0.1 * sin(movement_time * 0.8)
	var desired_velocity := move_direction * move_speed * ease_speed * drift
	horizontal_velocity = move_toward(horizontal_velocity, desired_velocity, 240.0 * delta)
	position.x = clampf(position.x + horizontal_velocity * delta, min_x, max_x)


func update_song_section() -> void:
	var new_section = 0

	if elapsed >= SHOWDOWN_TIME:
		new_section = 3
	elif elapsed >= FINAL_CLIMAX_TIME:
		new_section = 5
	elif elapsed >= CALM_TIME:
		new_section = 4
	elif elapsed >= SECOND_INSTRUMENT_TIME:
		new_section = 2
	elif elapsed >= DROP_TIME:
		new_section = 1

	if new_section == song_section:
		return

	song_section = new_section
	attack_index = 0
	spiral_remaining = 0

	match song_section:
		0:
			print("BOSS MUSIC: INTRO")
		1:
			print("BOSS MUSIC: THE ARRIVAL")
			shoot_timer = 1.2
		2:
			print("BOSS MUSIC: RISING PRESSURE")
			shoot_timer = 0.8
		3:
			print("Showdown()")
			shoot_timer = 0.55
		4:
			print("BOSS MUSIC: BREATHING ROOM")
			shoot_timer = 0.9
		5:
			print("BOSS MUSIC: FINAL CLIMAX")
			shoot_timer = 0.35


func update_phase() -> void:
	var new_phase = 1

	if health <= max_health * 0.35:
		new_phase = 3
	elif health <= max_health * 0.70:
		new_phase = 2

	if new_phase == phase:
		return

	phase = new_phase

	if phase == 2:
		move_speed = 90.0
		print("BOSS HEALTH PHASE 2")
	elif phase == 3:
		move_speed = 110.0
		print("BOSS HEALTH PHASE 3")

	health_changed.emit(health, max_health, phase)


func attack() -> void:
	if attacks_stopped or elapsed < DROP_TIME or elapsed >= SONG_END_TIME:
		return

	match song_section:
		1:
			arrival_attack()
		2:
			rising_pressure_attack()
		3:
			Showdown()
		4:
			breathing_room_attack()
		5:
			final_climax_attack()

	attack_index += 1


func arrival_attack() -> void:
	match attack_index % 3:
		0:
			start_spiral(10, 0.20, false)
		1:
			fire_fan(3, 24.0, 150.0, Color("#55E8FF"))
		2:
			fire_ring(10, 145.0, 0.0, Color("#FF55BB"))


func rising_pressure_attack() -> void:
	match attack_index % 3:
		0:
			start_spiral(16, 0.23, false)
		1:
			fire_fan(5, 48.0, 175.0, Color("#55E8FF"))
		2:
			fire_ring(14, 175.0, 0.12, Color("#FF55BB"))


func Showdown() -> void:
	match attack_index % 4:
		0:
			start_spiral(22, 0.25, true)
		1:
			fire_fan(7, 72.0, 195.0, Color("#FF55BB"))
		2:
			fire_ring(18, 190.0, 0.0, Color("#55E8FF"))
		3:
			fire_fan(5, 38.0, 215.0, Color("#FFE66D"))


func breathing_room_attack() -> void:
	match attack_index % 3:
		0:
			start_spiral(12, 0.19, false)
		1:
			fire_fan(3, 30.0, 155.0, Color("#55E8FF"))
		2:
			fire_ring(12, 155.0, 0.10, Color("#FF55BB"))


func final_climax_attack() -> void:
	match attack_index % 4:
		0:
			start_spiral(26, 0.29, true)
		1:
			fire_fan(9, 86.0, 210.0, Color("#FF55BB"))
		2:
			fire_ring(22, 205.0, 0.08, Color("#55E8FF"))
		3:
			fire_fan(7, 48.0, 225.0, Color("#FFE66D"))


func start_spiral(
	shot_count: int,
	angle_step: float,
	double_spiral: bool
) -> void:
	if attacks_stopped or elapsed >= SONG_END_TIME:
		return

	spiral_remaining = shot_count
	spiral_timer = 0.0
	spiral_angle = elapsed * 1.7
	spiral_angle_step = angle_step
	spiral_double = double_spiral


func get_spiral_interval() -> float:
	match song_section:
		1:
			return 0.12
		2:
			return 0.085
		3:
			return 0.065
		4:
			return 0.11
		5:
			return 0.05
		_:
			return 0.12


func fire_spiral_step() -> void:
	if attacks_stopped or elapsed >= SONG_END_TIME:
		spiral_remaining = 0
		return

	var direction = Vector2.RIGHT.rotated(spiral_angle)

	fire_bullet(
		direction,
		get_bullet_speed(),
		Color("#FF55BB")
	)

	if spiral_double:
		var second_direction = Vector2.RIGHT.rotated(
			-spiral_angle + PI
		)

		fire_bullet(
			second_direction,
			get_bullet_speed(),
			Color("#55E8FF")
		)

	spiral_angle += spiral_angle_step
	spiral_remaining -= 1


func fire_ring(
	count: int,
	bullet_speed: float,
	angle_offset: float,
	color: Color
) -> void:
	for i in range(count):
		if attacks_stopped or elapsed >= SONG_END_TIME:
			return

		var angle = TAU * float(i) / float(count) + angle_offset
		var direction = Vector2.RIGHT.rotated(angle)
		fire_bullet(direction, bullet_speed, color)


func fire_fan(
	count: int,
	spread_degrees: float,
	bullet_speed: float,
	color: Color,
	extra_angle: float = 0.0
) -> void:
	if attacks_stopped or elapsed >= SONG_END_TIME:
		return

	var player_node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	var aim_direction = (
		player_node.get_node("CollisionShape2D").global_position - global_position
	).normalized()

	var center_angle = aim_direction.angle() + extra_angle
	var spread = deg_to_rad(spread_degrees)

	if count == 1:
		fire_bullet(
			Vector2.RIGHT.rotated(center_angle),
			bullet_speed,
			color
		)
		return

	for i in range(count):
		var fraction = float(i) / float(count - 1)

		var angle = center_angle + lerpf(
			-spread / 2.0,
			spread / 2.0,
			fraction
		)

		fire_bullet(
			Vector2.RIGHT.rotated(angle),
			bullet_speed,
			color
		)


func get_bullet_speed() -> float:
	match song_section:
		1:
			return 145.0
		2:
			return 175.0
		3:
			return 195.0
		4:
			return 155.0
		5:
			return 210.0
		_:
			return 145.0


func fire_bullet(
	bullet_direction: Vector2,
	bullet_speed: float,
	color: Color = Color("#55E8FF")
) -> void:
	if attacks_stopped or elapsed >= SONG_END_TIME:
		return

	var bullet = enemy_bullet_scene.instantiate()
	preload("res://scripts/systems/combat_context.gd").root_for(self).add_child(bullet)

	bullet.global_position = global_position
	bullet.direction = bullet_direction.normalized()
	bullet.speed = bullet_speed

	if "bullet_color" in bullet:
		bullet.bullet_color = color


func set_attack_cooldown() -> void:
	match song_section:
		1:
			shoot_timer = 1.35
		2:
			shoot_timer = 1.0
		3:
			shoot_timer = 0.72
		4:
			shoot_timer = 1.2
		5:
			shoot_timer = 0.55
		_:
			shoot_timer = 1.0


func take_damage(amount: int) -> void:
	if defeated_already or attacks_stopped:
		return

	health = maxi(health - amount, 0)

	update_phase()
	health_changed.emit(health, max_health, phase)

	if health <= 0:
		defeated_already = true
		stop_attacking()
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		print("BOSS DEFEATED!")
		defeated.emit()
		_play_defeat()

func _play_defeat() -> void:
	if is_instance_valid(entrance_tween):
		entrance_tween.kill()
	var sprite: Sprite2D = $Sprite2D
	var resting_position := sprite.position
	var animation := create_tween()
	for offset in [8.0, -7.0, 5.0, -3.0, 0.0]:
		animation.tween_property(sprite, "position:x", resting_position.x + offset, 0.05)
		animation.parallel().tween_property(sprite, "modulate", Color(3, 3, 3) if offset > 0 else Color.WHITE, 0.05)
	animation.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await animation.finished
	defeat_finished.emit()
	queue_free()
