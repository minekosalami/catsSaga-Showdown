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
	var shimmer := 0.94 + 0.06 * sin(animation_time * 4.0)
	# Antialias the silhouette/rim only; interior layers are already inside it.
	# Radius never pulses: the saturated rim ends at the actual dangerous radius.
	draw_circle(Vector2.ZERO,body_radius+2.5,Color(bullet_color,0.055*shimmer))
	if visual_style == Style.FAST:
		for i in range(3):
			var start := -direction * (body_radius+float(i)*4)
			draw_line(start,start-direction*4,Color(bullet_color,0.24-float(i)*0.065),2-float(i)*0.4)
	elif visual_style == Style.DIAMOND:
		var corners := PackedVector2Array()
		for i in range(5):
			corners.append(Vector2.RIGHT.rotated(i*PI/2+animation_time*0.55)*body_radius*1.35)
		draw_polyline(corners,Color(bullet_color,0.3),1,true)
	draw_circle(Vector2.ZERO,body_radius,bullet_color.darkened(0.28))
	draw_arc(Vector2.ZERO,body_radius-0.6,0,TAU,32,bullet_color,1.2,true)
	draw_circle(Vector2.ZERO,body_radius*0.61,bullet_color.lightened(0.4))
	draw_circle(Vector2.ZERO,body_radius*0.32,Color(1,1,1,shimmer))
	if visual_style == Style.HEAVY:
		draw_arc(Vector2.ZERO,body_radius*0.77,0.2,TAU-0.2,28,bullet_color.lightened(0.5),0.8)
	if animation_time < 0.12:
		var birth := 1-animation_time/0.12
		draw_arc(Vector2.ZERO,body_radius+5*birth,0,TAU,24,Color(bullet_color,0.1*birth),1,true)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		area.take_damage(1)
		preload("res://scripts/ui/battle_burst.gd").spawn(get_parent(), global_position, bullet_color, 12)
		queue_free()
