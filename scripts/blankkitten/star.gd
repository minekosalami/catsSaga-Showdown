extends Node2D
signal defeated
signal damaged
const MAX_HEALTH := 5
const RADIUS := 8.0
@export var speed := 245.0
@export var gravity := 1250.0
@export var jump_speed := 465.0
@export var release_speed := 175.0
@export var hit_grace := 0.85
var health := MAX_HEALTH
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

func _ready() -> void:
	battle = get_parent()
	process_physics_priority = -10
	previous_position = position

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_Z and not event.echo:
		jump_held = event.pressed
		if event.pressed and not movement_locked:
			jump_requested = true
		elif not event.pressed:
			jump_released = true

func step(delta: float, direction: Vector2) -> void:
	previous_position = position
	invulnerability = maxf(0, invulnerability - delta)
	if movement_locked:
		velocity = Vector2.ZERO
		jump_requested = false
		jump_released = false
		return
	var rect: Rect2 = battle.arena_rect
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
	var direction := Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP)))
	step(delta,direction)
	queue_redraw()

func take_damage() -> void:
	if transition_safe or invulnerability > 0 or battle.game_over or battle.victory_started:
		return
	health = maxi(0,health-1)
	invulnerability = hit_grace
	damaged.emit()
	if health == 0:
		defeated.emit()

func _draw() -> void:
	var tint := Color.from_hsv(fposmod(clock*0.65,1),0.8,1)
	var points := PackedVector2Array()
	for i in range(10):
		points.append(Vector2.UP.rotated(i*PI/5+sin(clock*2)*0.06)*(13 if i%2 == 0 else 5.5))
	var alpha := 0.4 if invulnerability > 0 and fmod(clock,0.12) < 0.06 else 1.0
	draw_circle(Vector2.ZERO,18,Color(tint,0.09*alpha))
	draw_colored_polygon(points,Color(tint,alpha))
	points.append(points[0])
	draw_polyline(points,Color(1,1,1,alpha),1.5,true)
	draw_circle(Vector2.ZERO,2.0,Color.WHITE)
