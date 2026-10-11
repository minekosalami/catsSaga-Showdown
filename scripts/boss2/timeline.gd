extends Node2D

const BOUNDARIES := [0.0, 12.80, 38.40, 64.00, 70.40, 89.60, 140.80]
const PHASES := ["Introduction()", "Opening()", "LaserAssault()", "Intermission()", "Convergence()", "Finale()", "Survived()"]
const PROJECTILE_LIMIT := 240
@export_range(0.5, 3.0, 0.1) var warning_duration := 1.2
@export_range(1.0, 12.0, 0.1) var activation_duration := 6.0
@export_range(0.5, 12.0, 0.1) var movement_duration := 5.0
@export_range(1.0, 15.0, 0.1) var convergence_duration := 10.0
@export_range(1.0, 4.0, 0.1) var easing_power := 2.0
@export_range(8.0, 40.0, 1.0) var laser_width := 20.0
# 0 derives a gap of two original player sprite widths; positive values override.
@export var final_center_gap := 0.0
@export var maximum_inward_travel := 135.0
@export var side_offset := 185.0
@export var coordinated_travel := 45.0
var phase := -1
var attack_index := -1
var clock := 0.0
var resolved_gap := 194.0
var boss: Sprite2D
var lasers: Array[Area2D] = []
var battle: Node2D
const Projectile := preload("res://scenes/boss2/projectile.tscn")

func initialize() -> void:
	battle = get_parent()
	boss = $BossSprite
	boss.modulate.a = 0
	create_tween().tween_property(boss,"modulate:a",1.0,0.6)
	var player_sprite: Sprite2D = battle.player.get_node("Sprite2D")
	resolved_gap = final_center_gap if final_center_gap > 0 else player_sprite.texture.get_width() * absf(player_sprite.scale.x) * 2.0
	for index in range(2):
		var beam := Area2D.new()
		beam.set_script(preload("res://scripts/boss2/laser.gd"))
		beam.name = "LeftLaser" if index == 0 else "RightLaser"
		beam.beam_width = laser_width
		add_child(beam)
		lasers.append(beam)

func easing(progress: float) -> float:
	var p := clampf(progress, 0, 1)
	if p < 0.5:
		return pow(p * 2, easing_power) * 0.5
	return 1 - pow((1-p) * 2, easing_power) * 0.5

func advance(playback: float) -> void:
	clock = playback
	var next := 0
	for i in range(BOUNDARIES.size()):
		if clock >= BOUNDARIES[i]:
			next = i
	if next != phase:
		phase = next
		attack_index = -1
		battle.ui.show_phase(PHASES[phase])
		if phase in [3, 5, 6]:
			clear_hostiles()
		if phase == 6:
			battle.finish_survival()
			return
	_update_formation()
	if phase in [0, 3, 6]:
		return
	var interval := 1.20 if phase in [1,5] else (0.72 if phase == 2 else 0.65)
	var index := int((clock - BOUNDARIES[phase]) / interval)
	if index != attack_index:
		attack_index = index
		attack(index)

func _coordinated_center(local: float) -> float:
	# Cosine-eased travel starts centered with zero velocity, never snaps per cycle.
	return 270 + coordinated_travel * sin(PI * easing(fmod(local, movement_duration * 2) / (movement_duration * 2)) * 2)

func _update_formation() -> void:
	var center := 270.0
	var left := center - side_offset
	var right := center + side_offset
	var dangerous := false
	var warning := false
	var left_span := Rect2()
	var right_span := Rect2()
	if phase == 2:
		var local := clock - 38.40
		var cycle := fmod(local, warning_duration + activation_duration)
		center = _coordinated_center(local)
		left = center - side_offset
		right = center + side_offset
		warning = cycle < warning_duration
		dangerous = not warning
		left_span = Rect2(270-side_offset-coordinated_travel-laser_width/2,270, coordinated_travel*2+laser_width,630)
		right_span = Rect2(270+side_offset-coordinated_travel-laser_width/2,270, coordinated_travel*2+laser_width,630)
	elif phase == 3:
		center = lerpf(_coordinated_center(64.0-38.4), 270, easing((clock-64)/1.0))
	elif phase == 4:
		var local := clock - 70.40
		warning = local < warning_duration
		dangerous = not warning
		# Stops at explicit limits. Width is measured between solid inner edges.
		var travel := minf(maxf(0, maximum_inward_travel), maxf(0, side_offset-(resolved_gap+laser_width)/2))
		var amount := travel * easing((local-warning_duration)/maxf(0.1,convergence_duration))
		left += amount
		right -= amount
		left_span = Rect2(left-laser_width/2,270,travel+laser_width,630)
		right_span = Rect2(right-travel-laser_width/2,270,travel+laser_width,630)
	boss.position = Vector2(center,150)
	lasers[0].present(left,dangerous,warning,left_span,clock)
	lasers[1].present(right,dangerous,warning,right_span,clock)

func clear_hostiles() -> void:
	for projectile in get_tree().get_nodes_in_group("boss2_projectiles"):
		projectile.set_deferred("monitoring",false)
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		projectile.queue_free()
	for beam in lasers:
		beam.present(beam.position.x,false,false,Rect2(),clock)

func fire(direction: Vector2, speed: float, tint: Color) -> void:
	if get_tree().get_nodes_in_group("boss2_projectiles").size() >= PROJECTILE_LIMIT:
		return
	var projectile := Projectile.instantiate()
	projectile.direction = direction.normalized()
	projectile.speed = speed
	projectile.bullet_color = tint
	battle.add_child(projectile)
	projectile.position = boss.position + Vector2(0,55)

func ring(count: int, speed: float, offset: float, tint: Color, gap: float = 0.27) -> void:
	for i in range(count):
		var angle := TAU * i / count + offset
		if absf(wrapf(angle-PI/2,-PI,PI)) >= gap:
			fire(Vector2.RIGHT.rotated(angle),speed,tint)

func attack(index: int) -> void:
	var hard := phase in [2,4]
	var tint := Color("#6DDEFF") if not hard else Color("#A694FF")
	var kind := index % 3
	var opening_growth := mini(3,int(maxf(0,clock-12.80)/8.0)) if phase == 1 else 0
	if kind == 0:
		ring(22 if hard else 16 + opening_growth*2,145 if hard else 115 + opening_growth*5,clock * 0.11,tint,0.38 if phase == 4 else 0.27)
	elif kind == 1:
		# Successive symmetric rotating pairs form reusable circular spirals.
		for i in range(8 if hard else 5 + mini(2,opening_growth)):
			var angle := clock * 0.6 + i * 0.23
			fire(Vector2.RIGHT.rotated(angle),150 if hard else 120,tint)
			fire(Vector2.LEFT.rotated(-angle),150 if hard else 120,tint)
	else:
		var origin := boss.position + Vector2(0,55)
		var aim: Vector2 = (battle.player.get_node("CollisionShape2D").position + battle.player.position - origin).normalized()
		var half := 2 if phase != 4 else 1
		for i in range(-half,half+1):
			fire(aim.rotated(i * 0.14),155 if hard else 125,Color("#F5B7FF"))
