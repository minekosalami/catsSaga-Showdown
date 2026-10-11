extends Area2D
const Energy = preload("res://scripts/ui/energy_laser_style.gd")

@export_range(8.0, 40.0, 1.0) var beam_width := 20.0
@export var beam_top := 270.0
@export var beam_bottom := 900.0
var active := false
var warning := false
var warning_span := Rect2()
var energy_time := 0.0
var collision: CollisionShape2D
@export_range(0.0,1.0,0.05) var glow_strength := 0.65
var activation_clock := 0.0
var deactivation_clock := -10.0
@export var charge_duration := 1.2
var warning_clock := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.disabled = true
	add_child(collision)
	add_to_group("boss2_lasers")
	_configure_shape()

func _configure_shape() -> void:
	(collision.shape as RectangleShape2D).size = Vector2(beam_width, beam_bottom - beam_top)
	collision.position = Vector2(0, (beam_top + beam_bottom) * 0.5)

func present(x: float, dangerous: bool, show_warning: bool, span: Rect2, clock: float) -> void:
	position.x = x
	if show_warning and not warning:
		warning_clock = clock
	if dangerous and not active:
		activation_clock = clock
	if active and not dangerous:
		deactivation_clock = clock
	active = dangerous
	warning = show_warning
	warning_span = span
	energy_time = clock
	_configure_shape()
	collision.set_deferred("disabled", not active)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not active:
		return
	# Poll shape overlap every physics tick so sustained contact respects i-frames.
	# No one-time entered signal or damage during warning-only presentation.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 4):
		if hit.collider.is_in_group("player"):
			hit.collider.take_damage(1)

func _draw() -> void:
	if warning:
		var local := Rect2(warning_span.position-position,warning_span.size)
		var breathe := 0.16+0.03*sin(energy_time*3.0)
		draw_rect(local,Color(1,0.12,0.22,breathe))
		draw_rect(local,Color(1,0.32,0.38,0.8),false,1.5)
		for y in range(int(beam_top),int(beam_bottom),48):
			draw_line(Vector2(local.position.x,y),Vector2(local.end.x,y+16),Color(1,0.25,0.32,0.32),1,true)
		# A red dashed locator contrasts with the later continuous blue core.
		for y in range(int(beam_top),int(beam_bottom),32):
			draw_line(Vector2(0,y),Vector2(0,y+13),Color(1,0.55,0.58,0.85),2,true)
		var charge := smoothstep(0,maxf(0.1,charge_duration),energy_time-warning_clock)
		draw_line(Vector2(0,beam_top),Vector2(0,beam_bottom),Color(0.5,0.85,1,charge*0.4),3,true)
	var tail := 1-smoothstep(0.0,0.18,energy_time-deactivation_clock)
	if not active and (warning or tail <= 0):
		return
	var wake := smoothstep(0.0,0.18,maxf(0,energy_time-activation_clock))
	draw_set_transform(Vector2(0,(beam_top+beam_bottom)/2),PI/2)
	Energy.draw_beam(self,beam_bottom-beam_top,beam_width,Color("#167DFF"),energy_time,wake,glow_strength,1.0 if active else tail*0.35)
	draw_set_transform(Vector2.ZERO)
