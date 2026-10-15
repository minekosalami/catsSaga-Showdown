extends Area2D

signal health_changed(new_health: int)
signal game_over

# The sole enemy-projectile damage shape uses internal battle pixels.
@export_range(0.5, 32.0, 0.5) var damage_hitbox_radius: float = 7.5:
	set(value):
		damage_hitbox_radius = clampf(value, 0.5, 32.0)
		if is_node_ready():
			($CollisionShape2D.shape as CircleShape2D).radius = damage_hitbox_radius

@export var speed: float = 450.0
@export var focus_speed: float = 150.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var rainbow_beam_scene: PackedScene = preload("res://scenes/rainbow_beam.tscn")

var shoot_timer: float = 0.0
const SHOOT_INTERVAL: float = 0.15

var health: int = 3
var invulnerability_timer: float = 0.0
const INVULNERABILITY_DURATION: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var debug_hitbox_enabled := false

# SATURATE special attack.
var saturate_used: bool = false

# Hit animation state.
var hit_flash_timer: float = 0.0
const HIT_FLASH_DURATION: float = 0.14
var death_animation_started: bool = false

# Visual effects.
var visual_nodes: Array[CanvasItem] = []
var original_modulates: Dictionary = {}

# Secret CATA invincibility cheat.
var invincible: bool = false
var cheat_progress: int = 0
const CHEAT_CODE: String = "CATA"

# BEAM grants repeatable SATURATE without changing its normal single-use rule.
var unlimited_saturate: bool = false
var beam_cheat_progress: int = 0
const BEAM_CHEAT_CODE: String = "BEAM"


func _ready() -> void:
	# Give each instance its own shape so tuning one player cannot affect another.
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	($CollisionShape2D.shape as CircleShape2D).radius = damage_hitbox_radius
	add_to_group("player")
	$CollisionShape2D.position = $Sprite2D.position
	var grounding := preload("res://scripts/ui/player_grounding.gd").new()
	grounding.name = "PlayerGrounding"
	add_child(grounding)
	_collect_visual_nodes(self)


func _collect_visual_nodes(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var visual := child as CanvasItem
			visual_nodes.append(visual)
			original_modulates[visual] = visual.modulate

		_collect_visual_nodes(child)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_F3 and OS.is_debug_build():
		toggle_debug_hitbox()
		return

	# Press X to activate SATURATE.
	if event.keycode == KEY_X:
		activate_saturate()
		return

	# Secret CATA cheat.
	var key_text := OS.get_keycode_string(event.keycode).to_upper()

	if key_text.length() != 1 or not key_text in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		cheat_progress = 0
		beam_cheat_progress = 0
		return

	var beam_letter := BEAM_CHEAT_CODE.substr(beam_cheat_progress, 1)
	if key_text == beam_letter:
		beam_cheat_progress += 1
	else:
		beam_cheat_progress = 1 if key_text == "B" else 0
	if beam_cheat_progress >= BEAM_CHEAT_CODE.length():
		toggle_unlimited_saturate()
		beam_cheat_progress = 0

	var expected_letter := CHEAT_CODE.substr(cheat_progress, 1)

	if key_text == expected_letter:
		cheat_progress += 1
	else:
		if key_text == "C":
			cheat_progress = 1
		else:
			cheat_progress = 0

	if cheat_progress >= CHEAT_CODE.length():
		toggle_invincibility()
		cheat_progress = 0

func toggle_invincibility() -> void:
	invincible = not invincible
	print("CATA cheat activated: Invincibility ON" if invincible else "CATA cheat deactivated: Invincibility OFF")

func toggle_unlimited_saturate() -> void:
	unlimited_saturate = not unlimited_saturate
	print("BEAM cheat: Unlimited SATURATE ", "ON" if unlimited_saturate else "OFF")

func toggle_debug_hitbox() -> void:
	debug_hitbox_enabled = not debug_hitbox_enabled
	$HitboxDebug.visible = debug_hitbox_enabled or Input.is_key_pressed(KEY_SHIFT)


func _process(delta: float) -> void:
	if invulnerability_timer > 0.0:
		invulnerability_timer = maxf(
			0.0,
			invulnerability_timer - delta
		)

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(
			0.0,
			hit_flash_timer - delta
		)

	_update_visual_effects()
	if health <= 0:
		return

	# Normal shooting with Z.
	shoot_timer -= delta

	if Input.is_key_pressed(KEY_Z) and shoot_timer <= 0.0:
		shoot()
		shoot_timer = SHOOT_INTERVAL



func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	# Movement uses the same fixed step as enemy-projectile collisions.
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if direction.length() > 0.0:
		direction = direction.normalized()

	# Hold Shift for precision movement.
	var current_speed := speed

	if Input.is_key_pressed(KEY_SHIFT):
		current_speed = focus_speed

	# Smooth acceleration and deceleration.
	var target_velocity := direction * current_speed

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)

	position += velocity * delta

	# Keep player on screen.
	var screen_size := get_viewport_rect().size

	position.x = clampf(position.x, 16.0, screen_size.x - 16.0)
	position.y = clampf(position.y, 16.0, screen_size.y - 16.0)



func activate_saturate() -> void:
	if (saturate_used and not unlimited_saturate) or health <= 0:
		return

	if get_tree().paused:
		return

	var scene_root := preload("res://scripts/systems/combat_context.gd").root_for(self)

	if scene_root == null:
		return

	if rainbow_beam_scene == null:
		push_error("SATURATE: Rainbow beam scene is missing.")
		return

	if not is_instance_valid(rainbow_beam_scene):
		push_error("SATURATE: Rainbow beam scene is invalid.")
		return

	var beam := rainbow_beam_scene.instantiate()

	if beam == null:
		push_error("SATURATE: Could not instantiate rainbow beam.")
		return

	scene_root.add_child(beam)

	saturate_used = true
	print("SATURATE activated!")


func _update_visual_effects() -> void:
	var flash_active := hit_flash_timer > 0.0

	var blinking := (
		invulnerability_timer > 0.0
		and not invincible
		and not flash_active
	)

	var alpha := 1.0

	if blinking:
		alpha = (
			0.25
			if int(Time.get_ticks_msec() / 75.0) % 2 == 0
			else 1.0
		)

	var effect_color := Color(1.0, 1.0, 1.0, alpha)

	if flash_active:
		effect_color = Color(3.0, 3.0, 3.0, 1.0)

	for visual in visual_nodes:
		if not is_instance_valid(visual):
			continue

		var original_color: Color = original_modulates.get(
			visual,
			Color.WHITE
		)

		visual.modulate = original_color * effect_color


func shoot() -> void:
	var bullet = bullet_scene.instantiate()

	preload("res://scripts/systems/combat_context.gd").root_for(self).add_child(bullet)
	bullet.global_position = global_position + Vector2(0, -25)


func take_damage(amount: int) -> void:
	# Ignore queued collision callbacks after the boss has been defeated.
	if preload("res://scripts/systems/combat_context.gd").root_for(self).get("victory_started") == true:
		return

	if invincible:
		return

	if invulnerability_timer > 0.0 or health <= 0:
		return

	health = maxi(0, health - amount)
	invulnerability_timer = INVULNERABILITY_DURATION
	hit_flash_timer = HIT_FLASH_DURATION

	_spawn_hit_particles(false)

	# Trigger screen shake through main.gd.
	var main = preload("res://scripts/systems/combat_context.gd").root_for(self)

	if main != null:
		var current_shake = main.get("shake_time")
		var current_strength = main.get("shake_strength")

		if current_shake != null and current_strength != null:
			main.set("shake_time", maxf(float(current_shake), 0.16))
			main.set("shake_strength", maxf(float(current_strength), 4.0))

	health_changed.emit(health)
	print("Player health: ", health)

	if health <= 0:
		$HitboxDebug.hide()
		_play_death_effect()
		game_over.emit()
		print("GAME OVER")
		get_tree().paused = true


func _spawn_hit_particles(is_death: bool) -> void:
	var particles := CPUParticles2D.new()

	particles.name = "PlayerHitParticles"
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 1.0
	particles.lifetime = 0.8 if is_death else 0.45
	particles.amount = 28 if is_death else 10
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 90.0 if is_death else 65.0
	particles.initial_velocity_max = 230.0 if is_death else 150.0
	particles.scale_amount_min = 3.0 if is_death else 2.0
	particles.scale_amount_max = 5.0 if is_death else 3.0
	particles.color = Color.WHITE if is_death else Color("#FF70CB")
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.z_index = 20

	var scene_root := preload("res://scripts/systems/combat_context.gd").root_for(self)

	if scene_root == null:
		particles.free()
		return

	scene_root.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true

	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = particles.lifetime + 0.2
	cleanup_timer.process_mode = Node.PROCESS_MODE_ALWAYS

	particles.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(particles.queue_free)
	cleanup_timer.start()


func _play_death_effect() -> void:
	if death_animation_started:
		return

	death_animation_started = true
	hit_flash_timer = 0.0
	invulnerability_timer = 0.0

	_spawn_hit_particles(true)

	for visual in visual_nodes:
		if is_instance_valid(visual):
			visual.visible = false
