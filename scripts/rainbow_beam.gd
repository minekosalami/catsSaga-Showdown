extends Node2D

var elapsed: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var wall_y: float = 0.0

const CHARGE_TIME: float = 0.35
const SWEEP_TIME: float = 1.25
const WALL_THICKNESS: float = 30.0
const ORB_SPACING: float = 18.0
const ORB_RADIUS: float = 11.0
const DAMAGE: int = 30

var hit_targets: Array[Node] = []

var rainbow_colors: Array[Color] = [
	Color("#FF1744"),
	Color("#FF9100"),
	Color("#FFEA00"),
	Color("#00E676"),
	Color("#00B0FF"),
	Color("#651FFF"),
	Color("#F500FF")
]


func _ready() -> void:
	screen_size = get_viewport_rect().size
	position = Vector2.ZERO
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	wall_y = screen_size.y + WALL_THICKNESS

	print("SATURATE BEAM READY - viewport: ", screen_size)


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed < CHARGE_TIME:
		wall_y = screen_size.y - 55.0
	else:
		var progress: float = clampf(
			(elapsed - CHARGE_TIME) / SWEEP_TIME,
			0.0,
			1.0
		)

		# Accelerate as the wall travels upward.
		wall_y = lerpf(
			screen_size.y - 55.0,
			-WALL_THICKNESS,
			progress * progress
		)

	_damage_targets()
	_clear_enemy_bullets()
	queue_redraw()

	if elapsed >= CHARGE_TIME + SWEEP_TIME:
		queue_free()


func _draw() -> void:
	# Draw a bright background stripe so the attack is clearly visible.
	draw_rect(
		Rect2(
			Vector2(0.0, wall_y - WALL_THICKNESS),
			Vector2(screen_size.x, WALL_THICKNESS * 2.0)
		),
		Color(1.0, 1.0, 1.0, 0.25)
	)

	var count: int = int(ceil(screen_size.x / ORB_SPACING)) + 2

	for i in range(count):
		var x: float = float(i) * ORB_SPACING
		var color_offset: float = float(i) / float(count) + elapsed * 0.7
		var orb_color: Color = get_rainbow_color(color_offset)
		var orb_position := Vector2(x, wall_y)

		draw_circle(
			orb_position,
			ORB_RADIUS * 2.0,
			Color(orb_color.r, orb_color.g, orb_color.b, 0.25)
		)

		draw_circle(
			orb_position,
			ORB_RADIUS,
			orb_color
		)

		draw_circle(
			orb_position + Vector2(-3.0, -3.0),
			ORB_RADIUS * 0.35,
			Color.WHITE
		)

	# SATURATE() stays in the center of the screen.
	if int(elapsed * 12.0) % 2 == 0:
		var font: Font = ThemeDB.fallback_font
		var label: String = "Saturate()"
		var font_size: int = 48

		var text_size: Vector2 = font.get_string_size(
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		)

		var text_position := Vector2(
			(screen_size.x - text_size.x) / 2.0,
			(screen_size.y + font_size) / 2.0
		)

		draw_string(
			font,
			text_position + Vector2(2.0, 2.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.BLACK
		)

		draw_string(
			font,
			text_position,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)


func get_rainbow_color(value: float) -> Color:
	var wrapped: float = fposmod(value, 1.0)
	var scaled: float = wrapped * float(rainbow_colors.size())
	var index: int = int(floor(scaled))
	var next_index: int = (index + 1) % rainbow_colors.size()
	var blend: float = scaled - float(index)

	return rainbow_colors[index].lerp(
		rainbow_colors[next_index],
		blend
	)


func _damage_targets() -> void:
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("boss"))

	for target in targets:
		if not is_instance_valid(target):
			continue

		if target in hit_targets:
			continue

		if not target is Node2D:
			continue

		var target_node := target as Node2D

		if absf(target_node.global_position.y - wall_y) <= WALL_THICKNESS + 30.0:
			if target.has_method("take_damage"):
				target.call("take_damage", DAMAGE)
				hit_targets.append(target)
				print("SATURATE damaged: ", target.name)


func _clear_enemy_bullets() -> void:
	var bullets := get_tree().get_nodes_in_group("enemy_bullets")

	for bullet in bullets:
		if not is_instance_valid(bullet):
			continue

		if not bullet is Node2D:
			continue

		var bullet_node := bullet as Node2D

		if absf(bullet_node.global_position.y - wall_y) <= WALL_THICKNESS:
			bullet.queue_free()
