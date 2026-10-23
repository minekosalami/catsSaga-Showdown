extends Node2D

var tint := Color.WHITE
var duration := 0.4
var age := 0.0
var reach := 40.0

static func spawn(parent: Node, point: Vector2, color: Color, distance: float = 40.0) -> Node2D:
	if parent.get_tree().get_nodes_in_group("battle_bursts").size() >= 24:
		return null
	var burst := Node2D.new()
	burst.set_script(load("res://scripts/ui/battle_burst.gd"))
	burst.tint = color
	burst.reach = distance
	burst.z_index = 15
	parent.add_child(burst)
	burst.global_position = point
	return burst

func _ready() -> void:
	add_to_group("battle_bursts")

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= duration:
		queue_free()

func _draw() -> void:
	preload("res://scripts/ui/human_effects.gd").draw_impact(self,Vector2.ZERO,age,duration,reach*.65,tint)
	var progress := clampf(age / duration, 0, 1)
	var color := Color(tint, (1 - progress) * 0.65)
	for i in range(12):
		var direction := Vector2.RIGHT.rotated(TAU * i / 12.0 + 0.13)
		draw_line(direction * reach * progress, direction * (reach * progress + 8 * (1 - progress)), color, 1.5)
	draw_arc(Vector2.ZERO, reach * progress * 0.65, 0, TAU, 32, color, 1)
