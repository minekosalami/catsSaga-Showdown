extends CharacterBody2D

@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
var movement_locked: bool = false

func _physics_process(delta: float) -> void:
	if movement_locked or Session.busy:
		velocity = Vector2.ZERO
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()
	velocity = velocity.move_toward(direction * speed, (acceleration if direction != Vector2.ZERO else deceleration) * delta)
	move_and_slide()
