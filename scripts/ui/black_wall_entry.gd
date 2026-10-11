extends Control
## Reusable, viewport-sized battle curtain. Gameplay/music remain suspended
## until Session reveals the initialized battle and calls the host finish_entry.
@export_range(1.0, 1.5) var duration := 1.2
var progress := 0.0
var gap := 0.0
var impact_count := 0
var has_impacted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	hide()

func update_progress(value: float) -> void:
	progress = clampf(value, 0, 1)
	if progress < 0.7:
		gap = size.x * (1 - pow(progress / 0.7, 3))
	else:
		if not has_impacted:
			has_impacted = true
			impact_count += 1
		# Short elastic rebound, then a completely sealed join.
		gap = 20 * sin(PI * clampf((progress - 0.7) / 0.3, 0, 1)) * pow(1 - (progress - 0.7) / 0.3, 2)
	queue_redraw()

func close_walls() -> void:
	has_impacted = false
	modulate.a = 1
	show()
	update_progress(0)
	var tween := create_tween()
	tween.tween_method(update_progress, 0.0, 1.0, duration)
	await tween.finished

func _draw() -> void:
	var half := ceilf(size.x * 0.5)
	draw_rect(Rect2(-gap * 0.5, 0, half + 1, size.y), Color.BLACK)
	draw_rect(Rect2(size.x * 0.5 + gap * 0.5, 0, half + 1, size.y), Color.BLACK)
