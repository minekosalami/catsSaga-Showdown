extends Button

var selection_tween: Tween

func _draw() -> void:
	var selected := has_focus() or is_hovered()
	var ink := Color("#f4f0e7")
	draw_line(Vector2(18, size.y - 3), Vector2(size.x - 18, size.y - 4), Color(0.8, 0.8, 0.85, 0.12), 1.0, true)
	if selected:
		draw_polyline(PackedVector2Array([Vector2(22, size.y * 0.5 - 6), Vector2(29, size.y * 0.5), Vector2(22, size.y * 0.5 + 6)]), ink, 2.0, true)
		draw_circle(Vector2(size.x - 25, size.y * 0.5), 2.5, Color("#b6557f"))

func _ready() -> void:
	mouse_entered.connect(_selection_changed)
	mouse_exited.connect(_selection_changed)
	focus_entered.connect(_selection_changed)
	focus_exited.connect(_selection_changed)
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func _selection_changed() -> void:
	queue_redraw()
	if is_instance_valid(selection_tween):
		selection_tween.kill()
	var selected := has_focus() or is_hovered()
	selection_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selection_tween.tween_property(self, "scale", Vector2.ONE * (1.02 if selected else 1.0), 0.14)
