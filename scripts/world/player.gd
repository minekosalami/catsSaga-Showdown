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

func _ready() -> void:
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

func _physics_process(delta: float) -> void:
	if movement_locked or Session.busy:
		velocity = Vector2.ZERO
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()
	if direction != Vector2.ZERO:
		facing_direction = direction
	if direction.x != 0:
		facing_left = direction.x < 0
		sprite.flip_h = facing_left != artwork_faces_left
	var current_speed := speed * (sprint_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	velocity = velocity.move_toward(direction * current_speed, (acceleration if direction != Vector2.ZERO else deceleration) * delta)
	move_and_slide()
