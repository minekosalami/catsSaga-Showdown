extends Node2D

# Temporary labeled rectangles only. Replace this node; keep its siblings.
@export var box_size := Vector2(32, 32)
@export var tint := Color("#efc65e")
@export var caption: String = "TEMP"
@export var text_color := Color("#101115")

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-box_size * 0.5, box_size), tint)
	if not caption.is_empty():
		var font := preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
		var font_size := 14
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(-width * 0.5, 5), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
