
extends Area2D

@export var speed: float = 650.0

var orb_visual: Node2D
var animation_time: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Minimal glowing orb.
	orb_visual = Node2D.new()
	orb_visual.name = "OrbVisual"
	add_child(orb_visual)

	orb_visual.set_script(preload("res://scripts/ui/shot_visual.gd"))



func _add_circle(
	parent: Node2D,
	radius: float,
	tint: Color
) -> void:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()

	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		))

	circle.polygon = points
	circle.color = tint
	parent.add_child(circle)


func _process(delta: float) -> void:
	position.y -= speed * delta

	# Very subtle pulse.
	animation_time += delta
	var pulse := 1.0 + sin(animation_time * 8.0) * 0.035
	orb_visual.scale = Vector2.ONE * pulse

	if position.y < -30.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		area.take_damage(1)
		_spawn_impact_spark()
		queue_free()


func _spawn_impact_spark() -> void:
	var spark := Polygon2D.new()
	var points := PackedVector2Array()

	for i in range(8):
		var angle := TAU * float(i) / 8.0
		points.append(Vector2(
			cos(angle) * 4.0,
			sin(angle) * 4.0
		))

	spark.polygon = points
	spark.color = Color("#FF8BE8")

	var scene_root := preload("res://scripts/systems/combat_context.gd").root_for(self)
	if scene_root == null:
		spark.free()
		return

	scene_root.add_child(spark)
	spark.global_position = global_position

	var tween := spark.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(spark, "scale", Vector2.ZERO, 0.12)
	tween.parallel().tween_property(
		spark, "modulate:a", 0.0, 0.12
	)
	tween.tween_callback(spark.queue_free)
