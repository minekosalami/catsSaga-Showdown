extends Control

var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#18181b"))
	# Deterministic pencil marks: never consume the gameplay random generator.
	for i in range(36):
		var y := 18.0 + float(i) * size.y / 36.0
		var x := 18.0 + fmod(float(i * 83), maxf(size.x - 50.0, 1.0))
		draw_line(Vector2(x, y), Vector2(x + 10.0, y + 1.0), Color(0.9, 0.88, 0.85, 0.035), 1.0)
	var border := PackedVector2Array([Vector2(19, 22), Vector2(size.x - 21, 18), Vector2(size.x - 18, size.y - 20), Vector2(22, size.y - 18), Vector2(19, 22)])
	draw_polyline(border, Color("#777570"), 1.0, true)
	draw_rect(Rect2(Vector2(25, 25), size - Vector2(50, 50)), Color("#454447"), false, 1.0)
	# An original, quiet cat silhouette above the title.
	var origin := Vector2(size.x * 0.5, size.y * 0.5 - 245.0)
	var cat := PackedVector2Array([Vector2(-42, 20), Vector2(-47, -33), Vector2(-18, -15), Vector2(18, -17), Vector2(46, -35), Vector2(42, 20), Vector2(22, 33), Vector2(-22, 31), Vector2(-42, 20)])
	for i in range(cat.size()):
		cat[i] += origin
	draw_polyline(cat, Color("#b9b4ab"), 1.5, true)
	var alpha := 0.65 + sin(elapsed * 1.2) * 0.12
	draw_line(origin + Vector2(-22, 2), origin + Vector2(-13, 4), Color(0.89, 0.55, 0.8, alpha), 2.0)
	draw_line(origin + Vector2(13, 4), origin + Vector2(22, 2), Color(0.89, 0.55, 0.8, alpha), 2.0)
