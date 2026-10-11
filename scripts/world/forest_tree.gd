@tool
extends StaticBody2D

## Stable per-instance seed. Size never rerolls on entry or load.
@export var variation_seed: int = 1:
	set(value):
		variation_seed = value
		_refresh_if_ready()
## 0 uses the seeded size; set 0.7–1.5 to choose this tree's size manually.
@export_range(0.0, 1.5, 0.01) var size_override: float = 0.0:
	set(value):
		size_override = value
		_refresh_if_ready()
@export_range(32.0, 240.0, 1.0) var base_height: float = 140.0:
	set(value):
		base_height = value
		_refresh_if_ready()
var trunk_shape: CapsuleShape2D

func get_size_multiplier() -> float:
	if size_override > 0.0:
		return clampf(size_override, 0.7, 1.5)
	var random := RandomNumberGenerator.new()
	random.seed = variation_seed
	var weight := random.randf()
	if weight < 0.18:
		return random.randf_range(0.7, 0.88)
	if weight < 0.90:
		return random.randf_range(0.90, 1.20)
	return random.randf_range(1.25, 1.50)

func _ready() -> void:
	_apply_size()

func _refresh_if_ready() -> void:
	if is_inside_tree() and has_node("Sprite2D") and has_node("CollisionShape2D"):
		_apply_size()

func _apply_size() -> void:
	var sprite: Sprite2D = $Sprite2D
	if sprite.texture == null:
		return
	var factor := get_size_multiplier()
	var pixels := sprite.texture.get_size()
	var uniform_scale := base_height * factor / pixels.y
	sprite.scale = Vector2.ONE * uniform_scale
	# Anchor near the source tree's trunk base, retaining the root for Y-sorting.
	sprite.position = Vector2(-pixels.x * 0.5, -pixels.y * 17.0 / 18.0) * uniform_scale
	if trunk_shape == null:
		trunk_shape = CapsuleShape2D.new()
		$CollisionShape2D.shape = trunk_shape
	var trunk_scale := factor * base_height / 140.0
	trunk_shape.radius = 8.0 * trunk_scale
	trunk_shape.height = 24.0 * trunk_scale
	$CollisionShape2D.position = Vector2(0, -12) * trunk_scale
