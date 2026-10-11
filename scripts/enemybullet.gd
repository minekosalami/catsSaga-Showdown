extends Area2D

enum Style { STANDARD, FAST, HEAVY, DIAMOND }
const RADII := [6.5, 4.5, 8.0, 6.0]
@export var speed: float = 220.0
@export var bullet_color := Color("#873BFF")
@export_enum("Standard", "Fast", "Heavy", "Diamond") var visual_style: int = 0
@export var angular_velocity: float = 0.0
@export var turn_duration: float = 0.8
var direction: Vector2 = Vector2.DOWN
var animation_time := 0.0
var travel_time := 0.0
var body_radius := 6.5

func _ready() -> void:
	visual_style = clampi(visual_style, 0, 3)
	body_radius = RADII[visual_style]
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	($CollisionShape2D.shape as CircleShape2D).radius = body_radius
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Bounded curvature settles into straight travel; no homing or sudden turns.
	if travel_time < turn_duration:
		var turn_step := minf(delta, turn_duration - travel_time)
		direction = direction.rotated(angular_velocity * turn_step)
	travel_time += delta
	global_position += direction * speed * delta
	var bounds := get_viewport_rect().size
	if global_position.y < -40 or global_position.y > bounds.y + 40 or global_position.x < -40 or global_position.x > bounds.x + 40:
		queue_free()

func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(animation_time * 5.0)
	# The filled disk and its bright outline stay at the exact dangerous radius.
	draw_circle(Vector2.ZERO, body_radius + 2.0, Color(bullet_color, 0.09 * pulse))
	if visual_style == Style.FAST:
		draw_line(-direction * body_radius, -direction * (body_radius + 12), Color(bullet_color, 0.22), 2)
	elif visual_style == Style.DIAMOND:
		var corners := PackedVector2Array()
		for i in range(5):
			corners.append(Vector2.RIGHT.rotated(i * PI / 2 + animation_time * 0.7) * body_radius * 1.42)
		draw_polyline(corners, Color(bullet_color, 0.5), 1)
	draw_circle(Vector2.ZERO, body_radius, bullet_color.darkened(0.15))
	draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, bullet_color.lightened(0.55), 1.0 if visual_style != Style.HEAVY else 1.5)
	draw_circle(Vector2.ZERO, body_radius * 0.48, bullet_color.lightened(0.75))
	draw_circle(Vector2(-1, -1), body_radius * 0.23, Color.WHITE)
	if animation_time < 0.12:
		draw_arc(Vector2.ZERO, body_radius + 7 * (1 - animation_time / 0.12), 0, TAU, 20, Color(bullet_color, 0.12 * (1 - animation_time / 0.12)), 1)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		area.take_damage(1)
		preload("res://scripts/ui/battle_burst.gd").spawn(get_parent(), global_position, bullet_color, 12)
		queue_free()
