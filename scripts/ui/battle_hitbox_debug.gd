extends Node2D

# Focus and developer visualization both read the authoritative damage shape.
var display_radius := 7.0

func _process(_delta: float) -> void:
	var player: Node = get_parent()
	visible = player.health > 0 and (Input.is_key_pressed(KEY_SHIFT) or player.debug_hitbox_enabled)
	if visible:
		position = get_parent().get_node("CollisionShape2D").position
		display_radius = get_parent().get_node("CollisionShape2D").shape.radius
		queue_redraw()

func _draw() -> void:
	var radius: float = get_parent().get_node("CollisionShape2D").shape.radius
	draw_circle(Vector2.ZERO, radius + 2, Color(0.4, 0.9, 1.0, 0.10 + 0.04 * sin(Time.get_ticks_msec() * 0.004)))
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.9, 1.0, 0.3))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 1.0)
