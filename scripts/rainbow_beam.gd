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
var charge_origin := Vector2.ZERO
@export_range(0.0, 1.0, 0.05) var visual_intensity := 0.7

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
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		charge_origin = player.get_node("CollisionShape2D").global_position - global_position
	var game := get_parent()
	game.shake_time = maxf(game.shake_time, 0.18)
	game.shake_strength = maxf(game.shake_strength, 3.0)
	preload("res://scripts/ui/battle_burst.gd").spawn(game, charge_origin, Color("#F5B7FF"), 45)

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
	if elapsed < CHARGE_TIME:
		var charge := elapsed / CHARGE_TIME
		for i in range(14):
			var angle := TAU * i / 14 + elapsed * 3
			var color := get_rainbow_color(float(i) / 14 + elapsed)
			var radius := lerpf(40, 17, charge)
			draw_circle(charge_origin + Vector2.RIGHT.rotated(angle) * radius, 2.5, Color(color, visual_intensity))
		draw_circle(charge_origin, 14 + charge * 8, Color(1,1,1,0.12 * visual_intensity))
		draw_arc(charge_origin, 18 + charge * 10, 0, TAU, 48, Color.WHITE, 1.5)
	# A sweeping horizontal beam retains the original damage/clearing trajectory.
	for band in range(4):
		var spread := WALL_THICKNESS + band * 7
		draw_rect(Rect2(0, wall_y - spread, screen_size.x, spread * 2), Color(0.7,0.45,1,0.035 * visual_intensity))
	var count := ceili(screen_size.x / ORB_SPACING) + 2
	for i in range(count):
		var x := i * ORB_SPACING
		var color := get_rainbow_color(float(i)/count + elapsed * 0.65)
		var wave := sin(x * 0.045 + elapsed * 7) * 4
		for side in [-1, 1]:
			draw_circle(Vector2(x, wall_y + side * (15 + wave)), ORB_RADIUS, color)
			draw_circle(Vector2(x, wall_y + side * (15 + wave)), ORB_RADIUS * 0.42, color.lightened(0.6))
		var particle_y := wall_y + sin(i * 1.7 + elapsed * 4) * 45
		draw_circle(Vector2(fposmod(x + elapsed * 160, screen_size.x), particle_y), 1.8, Color(color, visual_intensity))
	draw_rect(Rect2(0, wall_y - 7, screen_size.x, 14), Color.WHITE)
	var font: Font = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
	var label := "SATURATE()"
	var font_size := 38
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var point := Vector2((screen_size.x - text_size.x)/2, (screen_size.y + font_size)/2)
	var alpha := minf(elapsed / 0.12, 1.0) * minf((CHARGE_TIME + SWEEP_TIME - elapsed)/0.18, 1.0)
	draw_string(font, point + Vector2(2,2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0,0,0,alpha))
	draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1,1,1,alpha))


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
				preload("res://scripts/ui/battle_burst.gd").spawn(get_parent(), target_node.global_position, Color("#FFE66D"), 65)
				if target.has_signal("health_changed"):
					get_parent().get_node("UI").show_impact_flash()
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
