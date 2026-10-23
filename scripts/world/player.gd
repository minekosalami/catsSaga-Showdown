extends CharacterBody2D

@export var speed: float = 260.0
@export var sprint_multiplier: float = 1.5
@export var sprite_texture: Texture2D
@export var sprite_height: float = 64.0
@export var artwork_faces_left: bool = true
var facing_left: bool = true
var facing_direction := Vector2.LEFT
var sprite: Sprite2D

func face_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO: return
	facing_direction = direction.normalized()
	if direction.x != 0:
		facing_left = direction.x < 0
		sprite.flip_h = facing_left != artwork_faces_left

@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
var movement_locked: bool = false
var previous_physics_position := Vector2.ZERO
var physics_position := Vector2.ZERO

func _ready() -> void:
	previous_physics_position = global_position
	physics_position = global_position
	sprite = Sprite2D.new()
	sprite.name = "PlayerSprite"
	add_child(sprite)
	if sprite_texture != null:
		sprite.texture = sprite_texture
		sprite.scale = Vector2.ONE * sprite_height / float(sprite_texture.get_height())
		$VisualPlaceholder.hide()
	var movement_visual := preload("res://scripts/world/movement_visual.gd").new()
	movement_visual.name = "MovementVisual"
	add_child(movement_visual)

func visual_position() -> Vector2:
	# Interpolate only exploration presentation. The body and its collisions stay
	# on the fixed physics tick; teleports must never interpolate through terrain.
	if not global_position.is_equal_approx(physics_position):return global_position
	return previous_physics_position.lerp(physics_position,clampf(Engine.get_physics_interpolation_fraction(),0.0,1.0))

func _process(_delta: float) -> void:
	if Session.busy:return
	var correction := visual_position()-global_position
	sprite.position = correction
	get_node("MovementVisual").position = correction

func _physics_process(delta: float) -> void:
	if not global_position.is_equal_approx(physics_position):
		physics_position = global_position
	previous_physics_position = physics_position
	if movement_locked or Session.busy:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	if direction != Vector2.ZERO:
		facing_direction = direction
	if direction.x != 0:
		facing_left = direction.x < 0
		sprite.flip_h = facing_left != artwork_faces_left
	var current_speed := speed * (sprint_multiplier if Input.is_action_pressed("focus") else 1.0)
	velocity = velocity.move_toward(direction * current_speed, (acceleration if direction != Vector2.ZERO else deceleration) * delta)
	move_and_slide()
	physics_position = global_position
