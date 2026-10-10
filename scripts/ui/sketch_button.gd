extends Button

var selection_tween: Tween

func _draw() -> void:
	var ink := Color("#777570")
	draw_line(Vector2(4, 3), Vector2(size.x - 7, 2), ink, 1.0, true)
	draw_line(Vector2(3, size.y - 4), Vector2(size.x - 4, size.y - 2), ink, 1.0, true)

func _ready() -> void:
	mouse_entered.connect(_selection_changed)
	mouse_exited.connect(_selection_changed)
	focus_entered.connect(_selection_changed)
	focus_exited.connect(_selection_changed)
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func _selection_changed() -> void:
	if is_instance_valid(selection_tween):
		selection_tween.kill()
	var selected := has_focus() or is_hovered()
	selection_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selection_tween.tween_property(self, "scale", Vector2.ONE * (1.025 if selected else 1.0), 0.14)
