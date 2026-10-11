extends Area2D

@export_range(8.0, 40.0, 1.0) var beam_width := 20.0
@export var beam_top := 270.0
@export var beam_bottom := 900.0
var active := false
var warning := false
var warning_span := Rect2()
var energy_time := 0.0
var collision: CollisionShape2D

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
		var local := Rect2(warning_span.position - position, warning_span.size)
		draw_rect(local, Color(1, 0.12, 0.22, 0.16))
		draw_rect(local, Color(1, 0.3, 0.35, 0.7), false, 2)
		for y in range(int(beam_top), int(beam_bottom), 40):
			draw_line(Vector2(local.position.x, y), Vector2(local.end.x, y + 18), Color(1, 0.2, 0.3, 0.26), 1)
	if not active:
		return
	var height := beam_bottom - beam_top
	for extra in [12.0, 6.0]:
		draw_rect(Rect2(-beam_width/2-extra, beam_top, beam_width+extra*2, height), Color(0.05, 0.45, 1, 0.07))
	# Solid blue dangerous body exactly matches the rectangle; outer glow is faint.
	draw_rect(Rect2(-beam_width/2, beam_top, beam_width, height), Color(0.04, 0.42, 1, 0.88))
	draw_rect(Rect2(-beam_width * 0.16, beam_top, beam_width * 0.32, height), Color(0.8, 0.97, 1, 0.95))
	draw_line(Vector2(-beam_width/2, beam_top), Vector2(-beam_width/2, beam_bottom), Color(0.4, 0.8, 1), 1)
	draw_line(Vector2(beam_width/2, beam_top), Vector2(beam_width/2, beam_bottom), Color(0.4, 0.8, 1), 1)
	for i in range(16):
		var y := beam_top + fmod(i * 43.0 + energy_time * 75, height)
		draw_line(Vector2(-beam_width * 0.3, y), Vector2(beam_width * 0.3, y + 8), Color(0.7, 0.92, 1, 0.35), 2)
