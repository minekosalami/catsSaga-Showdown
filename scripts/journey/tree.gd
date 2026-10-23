@tool
extends StaticBody2D
## Baked deterministic size, editable per tree. Trunk and artwork scale together.
@export_range(.7,1.5,.01) var size_multiplier := 1.0:
	set(value):
		size_multiplier = value
		if is_inside_tree(): refresh()
func _ready() -> void: refresh()
func refresh() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sprite == null or collision == null or sprite.texture == null:return
	var height := 142.0*size_multiplier
	sprite.scale = Vector2.ONE*height/sprite.texture.get_height()
	sprite.position.y = -height*.43
	var shadow := get_node_or_null("GroundShadow") as Sprite2D
	if shadow != null: shadow.scale = Vector2(height*.40/12,height*.10/8)
	var trunk := collision.shape as CapsuleShape2D
	if trunk == null or not is_equal_approx(trunk.radius,9*size_multiplier) or not is_equal_approx(trunk.height,25*size_multiplier):
		trunk = CapsuleShape2D.new()
		trunk.radius = 9*size_multiplier
		trunk.height = 25*size_multiplier
		collision.shape = trunk
	collision.position.y = -7.5*size_multiplier
