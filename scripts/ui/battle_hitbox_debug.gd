extends Node2D

# Optional developer visualization; normal gameplay leaves this node hidden.
func _process(_delta: float) -> void:
	if visible:
		position = get_parent().get_node("CollisionShape2D").position
		queue_redraw()

func _draw() -> void:
	var radius: float = get_parent().damage_hitbox_radius
	draw_circle(Vector2.ZERO, radius, Color(1, 0.2, 0.5, 0.35))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 1.0)
