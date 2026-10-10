extends Node2D

func _draw() -> void:
	# Original ink-framed terminal token; distinct from cats and round bullets.
	var shell := PackedVector2Array([Vector2(-19, -17), Vector2(0, -25), Vector2(19, -17), Vector2(22, 13), Vector2(0, 24), Vector2(-22, 13)])
	draw_colored_polygon(shell, Color("#111218"))
	shell.append(shell[0])
	draw_polyline(shell, Color("#eeeae2"), 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(-10, -7), Vector2(-15, 0), Vector2(-10, 7)]), Color("#eeeae2"), 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(10, -7), Vector2(15, 0), Vector2(10, 7)]), Color("#eeeae2"), 2.0, true)
	draw_line(Vector2(3, -8), Vector2(-3, 8), Color("#e498bc"), 2.0, true)
	draw_line(Vector2(-8, 17), Vector2(7, 18), Color("#888890"), 1.0, true)
