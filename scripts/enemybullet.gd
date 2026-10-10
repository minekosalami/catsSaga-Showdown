
extends Area2D

@export var speed: float = 220.0
var direction: Vector2 = Vector2.DOWN

var orb_visual: Node2D
var animation_time: float = 0.0


func _ready() -> void:
	# Create a minimal violet orb.
	orb_visual = Node2D.new()
	orb_visual.name = "EnemyOrbVisual"
	add_child(orb_visual)

	_add_circle(orb_visual, 10.0, Color(0.55, 0.15, 1.0, 0.12))
	_add_circle(orb_visual, 6.5, Color("#873BFF"))
	_add_circle(orb_visual, 4.0, Color("#C5A0FF"))
	_add_circle(orb_visual, 2.0, Color("#FFFFFF"))

	# Detect collisions with the player.
	area_entered.connect(_on_area_entered)


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
	# Preserve the original movement and direction.
	global_position += direction * speed * delta

	# Subtle pulse.
	animation_time += delta
	var pulse := 1.0 + sin(animation_time * 7.0) * 0.04
	orb_visual.scale = Vector2.ONE * pulse

	# Remove bullets that leave the screen.
	var screen_size := get_viewport_rect().size

	if global_position.y < -40.0 or global_position.y > screen_size.y + 40.0:
		queue_free()
	elif global_position.x < -40.0 or global_position.x > screen_size.x + 40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		area.take_damage(1)
		queue_free()
