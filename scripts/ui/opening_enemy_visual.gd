extends Node2D

var clock := 0.0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2(0,2),25,Color("#0a0c18"))
	draw_texture_rect(preload("res://scripts/ui/human_effects.gd").frame("flame",int(clock*12)),Rect2(-18,-30,36,58),false)
	draw_arc(Vector2.ZERO,24,clock*.2,clock*.2+TAU*.72,32,Color("#e7a5c6"),1,true)
