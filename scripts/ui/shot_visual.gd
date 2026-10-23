extends Node2D
const Energy = preload("res://scripts/ui/projectile_energy.gd")
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	Energy.draw_motion_trail(self,5.0,Color("#FF38D4"),Vector2.UP,get_parent().speed)
	Energy.draw_orb(self,5.0,Color("#FF38D4"),get_parent().animation_time)
