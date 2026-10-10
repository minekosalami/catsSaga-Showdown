extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := size * 0.5
	var ink := Color("#202126")
	# Two imperfect rings and a cat drawn only with original pencil-like strokes.
	for ring in range(2):
		var points := PackedVector2Array()
		for i in range(81):
			var a := float(i) * TAU / 80.0
			var r := 70.0 + sin(a * 7.0 + ring) * 1.7 + ring * 4.0
			points.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(points, Color(0.1, 0.1, 0.12, 0.7 if ring == 0 else 0.25), 1.2, true)
	var cat := PackedVector2Array([Vector2(-45, 27), Vector2(-49, -43), Vector2(-20, -22), Vector2(20, -24), Vector2(50, -46), Vector2(43, 29), Vector2(20, 43), Vector2(-23, 41), Vector2(-45, 27)])
	for i in range(cat.size()):
		cat[i] += c
	draw_polyline(cat, ink, 2.0, true)
	for side in [-1, 1]:
		var x: float = side * 22.0
		draw_line(c + Vector2(x - 8, 1), c + Vector2(x + 7, -2), ink, 2.0, true)
		for j in range(3):
			draw_line(c + Vector2(side * 29, 15 + j * 5), c + Vector2(side * 62, 7 + j * 10), ink, 1.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(-5, 12), c + Vector2(0, 16), c + Vector2(5, 12)]), ink, 1.5, true)
	draw_circle(c + Vector2(0, -92), 2.0, Color("#b6557f"))
	draw_line(c + Vector2(-90, 0), c + Vector2(-81, 0), ink)
	draw_line(c + Vector2(81, 0), c + Vector2(90, 0), ink)
