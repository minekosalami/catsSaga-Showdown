
extends Area2D

@export var speed: float = 100.0
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemybullet.tscn")

var health: int = 3
var shoot_timer: float = 1.0

func _ready() -> void:
	add_to_group("enemies")

	add_to_group("opening_enemies")
	var visual := Node2D.new()
	visual.name = "InkToken"
	visual.set_script(preload("res://scripts/ui/opening_enemy_visual.gd"))
	add_child(visual)

func _process(delta: float) -> void:
	position.y += speed * delta

	if position.y > get_viewport_rect().size.y + 30:
		queue_free()
		return

	shoot_timer -= delta

	if shoot_timer <= 0.0:
		shoot_at_player()
		shoot_timer = 1.8

func shoot_at_player() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var bullet = enemy_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position
	bullet.direction = (player.global_position - global_position).normalized()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
