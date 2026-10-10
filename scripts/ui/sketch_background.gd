extends Control

var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#f4f0e7"))
	# Original deterministic paper grain. No shared gameplay RNG is consumed.
	for i in range(650):
		var p := Vector2(fmod(i * 71.3, size.x), fmod(i * 119.7, size.y))
		draw_line(p, p + Vector2(2.0 + i % 4, 0.6), Color(0.15, 0.15, 0.18, 0.035), 1.0)
	var ink := Color("#27282c")
	var frame := PackedVector2Array([Vector2(24, 28), Vector2(size.x - 28, 25), Vector2(size.x - 25, size.y - 26), Vector2(27, size.y - 24), Vector2(24, 28)])
	draw_polyline(frame, ink, 1.2, true)
	for corner in [Vector2(34, 35), Vector2(size.x - 35, size.y - 35)]:
		draw_line(corner - Vector2(7, 0), corner + Vector2(7, 0), ink)
		draw_line(corner - Vector2(0, 7), corner + Vector2(0, 7), ink)
	# Very slow moving shadow along the paper's edge, outside the composition.
	var y := size.y * (0.5 + 0.08 * sin(elapsed * 0.35))
	draw_line(Vector2(25, y - 50), Vector2(25, y + 50), Color("#b6557f"), 2.0)
