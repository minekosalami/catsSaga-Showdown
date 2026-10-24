extends Node2D
signal defeated
signal damaged
signal hp_damaged
var item_mode := false
var shield_remaining := 0.0
var max_health: int:
	get: return Session.rpg.max_hp()
const Cue = preload("res://scripts/blankkitten/timeline.gd")
const RADIUS := 13.75
const INNER_EDGE := 1.0
const CHEAT_CODE := "CATA"
var invincible := false
var cheat_progress := 0
@export var speed := 245.0
@export var gravity := 1250.0
@export var jump_speed := 465.0
@export var release_speed := 175.0
@export var hit_grace := 0.85
var health := 20
var velocity := Vector2.ZERO
var previous_position := Vector2.ZERO
var gravity_mode := false
var movement_locked := false
var transition_safe := true
var grounded := false
var invulnerability := 0.0
var clock := 0.0
var jump_requested := false
var jump_released := false
var jump_held := false
var battle: Node
var ground_shadow: Sprite2D

func _ready() -> void:
	battle = get_parent()
	health=Session.rpg.max_hp()
	process_physics_priority = -10
	previous_position = position
	ground_shadow = Sprite2D.new()
	ground_shadow.name = "GroundingShadow"
	ground_shadow.texture = preload("res://assets/wonderland_human/ninja/Shadow.png")
	ground_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_shadow.scale = Vector2(2.2,.7)
	ground_shadow.modulate.a = .3
	ground_shadow.z_index = -1
	ground_shadow.hide()
	add_child(ground_shadow)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not battle.game_over and not battle.victory_started:
		var letter := OS.get_keycode_string(event.keycode).to_upper()
		if letter.length() != 1 or not letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
			cheat_progress = 0
		else:
			cheat_progress = cheat_progress+1 if letter == CHEAT_CODE.substr(cheat_progress,1) else (1 if letter == "C" else 0)
			if cheat_progress == CHEAT_CODE.length():
				toggle_invincibility()
				cheat_progress = 0
	if event.is_action("attack") and not event.is_echo() and not item_mode:
		jump_held = event.pressed
		if event.pressed and not movement_locked:
			jump_requested = true
		elif not event.pressed:
			jump_released = true

func toggle_invincibility() -> void:
	invincible = not invincible
	print("CATA cheat: Invincibility ","ON" if invincible else "OFF")

func step(delta: float, direction: Vector2) -> void:
	previous_position = position
	invulnerability = maxf(0, invulnerability - delta)
	shield_remaining=maxf(0,shield_remaining-delta)
	if movement_locked or item_mode:
		velocity = Vector2.ZERO
		jump_requested = false
		jump_released = false
		return
	var rect: Rect2 = battle.arena_rect.grow(-INNER_EDGE)
	if gravity_mode:
		velocity.x = direction.x * speed
		if jump_requested and grounded:
			velocity.y = -jump_speed
			grounded = false
		if jump_released and velocity.y < -release_speed:
			velocity.y = -release_speed
		velocity.y += gravity * delta
	else:
		velocity = direction.limit_length(1) * speed
	jump_requested = false
	jump_released = false
	position += velocity * delta
	position.x = clampf(position.x, rect.position.x+RADIUS, rect.end.x-RADIUS)
	position.y = clampf(position.y, rect.position.y+RADIUS, rect.end.y-RADIUS)
	if gravity_mode:
		grounded = position.y >= rect.end.y - RADIUS - 0.001
		if grounded:
			velocity.y = 0
		elif position.y <= rect.position.y + RADIUS:
			velocity.y = maxf(0,velocity.y)

func _physics_process(delta: float) -> void:
	clock = battle.elapsed_time
	if battle.game_over or battle.victory_started:
		return
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	step(delta,direction)
	queue_redraw()

func take_damage() -> void:
	if invincible or shield_remaining>0 or transition_safe or invulnerability > 0 or battle.game_over or battle.victory_started:
		return
	health = maxi(0,health-4)
	hp_damaged.emit()
	invulnerability = hit_grace
	queue_redraw()
	damaged.emit()
	battle.feedback.hit(position,battle.elapsed_time)
	if health == 0:
		defeated.emit()
		Session.respawn_checkpoint.call_deferred()

func player_tint(time: float) -> Color:
	var duration := Cue.END-Cue.STARTS[7]
	var progress := clampf((time-Cue.STARTS[7])/duration,0,1)
	# Integral of 1-smoothstep: color-cycle velocity falls continuously to zero.
	var resolved_clock := minf(time,Cue.STARTS[7])+duration*(progress-pow(progress,3)+.5*pow(progress,4))
	return Color.from_hsv(fposmod(resolved_clock*.65,1),.8,1)

func _draw() -> void:
	ground_shadow.visible = health>0 and gravity_mode
	if health <= 0: return
	# In gravity sections the shadow stays on the actual floor during a jump.
	if gravity_mode and "arena_rect" in battle:
		ground_shadow.position = Vector2(0,battle.arena_rect.end.y-position.y-3)
	var bob := sin(clock*9)*.4 if velocity.length()>15 and not gravity_mode else 0.0
	draw_set_transform(Vector2(0,bob))
	var tint := player_tint(clock)
	var points := PackedVector2Array()
	for i in range(10):
		points.append(Vector2.DOWN.rotated(i*PI/5)*(13 if i%2 == 0 else 5.5))
	var alpha := 0.4 if invulnerability > 0 and fmod(clock,0.12) < 0.06 else 1.0
	draw_circle(Vector2.ZERO,18,Color(tint,0.09*alpha))
	draw_colored_polygon(points,Color(tint,alpha))
	points.append(points[0])
	draw_polyline(points,Color(1,1,1,alpha),1.5,true)
	draw_circle(Vector2.ZERO,2.0,Color.WHITE)
	if invincible: draw_arc(Vector2.ZERO,20,clock,clock+PI*1.5,24,Color(tint,.65),1,true)
