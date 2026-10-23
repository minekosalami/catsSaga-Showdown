extends Node2D

const BOUNDARIES := [0.0, 12.80, 38.40, 64.00, 70.40, 89.60, 140.80]
const PHASES := ["Introduction()", "Opening()", "LaserAssault()", "RICOCHET()", "CrossLaser()", "Finale()", "Survived()"]
const PROJECTILE_LIMIT := 240
# Density and cadence remain independent of the requested normal speed increase.
@export_range(1.0,1.6,0.05) var difficulty_multiplier := 1.25
@export_range(0.5, 3.0, 0.1) var warning_duration := 1.2
@export_range(1.0, 12.0, 0.1) var activation_duration := 6.0
@export_range(0.5, 12.0, 0.1) var movement_duration := 5.0
@export_range(1.0, 4.0, 0.1) var easing_power := 2.0
@export_range(8.0, 40.0, 1.0) var laser_width := 20.0
@export var normal_speed_multiplier := 1.3
const RICOCHET_LIMIT := 30
const MEASURE_SECONDS := 1.6
@export var side_offset := 185.0
@export var coordinated_travel := 45.0
var phase := -1
var attack_index := -1
var clock := 0.0
var boss: Sprite2D
var lasers: Array[Area2D] = []
var cross: Node2D
var battle: Node2D
const Projectile := preload("res://scenes/boss2/projectile.tscn")

func initialize() -> void:
	battle = get_parent()
	boss = $BossSprite
	cross = $RotatingCross
	boss.modulate.a = 0
	create_tween().tween_property(boss,"modulate:a",1.0,0.6)
	for index in range(2):
		var beam := Area2D.new()
		beam.set_script(preload("res://scripts/boss2/laser.gd"))
		beam.name = "LeftLaser" if index == 0 else "RightLaser"
		beam.beam_width = laser_width
		beam.charge_duration = warning_duration
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
		# Clear before spawning the new phase. Cross shards survive only its finale transition.
		clear_hostiles(phase == 5,phase == 4)
		if phase == 6:
			battle.finish_survival()
			return
	_update_formation()
	if phase in [0,4,6]:
		return
	var interval := MEASURE_SECONDS if phase in [3,5] else (1.20 if phase == 1 else 0.72)/difficulty_multiplier
	var index := int((clock-BOUNDARIES[phase]+0.000001)/interval)
	if index != attack_index:
		attack_index = index
		if phase == 3:
			fire_ricochet_volley(index)
		else:
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
		left_span = Rect2(left-laser_width/2,270,laser_width,630)
		right_span = Rect2(right-laser_width/2,270,laser_width,630)
	elif phase == 3:
		center = lerpf(_coordinated_center(64.0-38.4),270,easing((clock-64)/1.0))
	elif phase != 4:
		center += sin(clock*TAU/9.6)*20
	boss.position = Vector2(center,205)
	lasers[0].present(left,dangerous,warning,left_span,clock)
	lasers[1].present(right,dangerous,warning,right_span,clock)
	cross.sample(clock)

func clear_hostiles(preserve_cross_shards: bool = false, shatter_ricochets: bool = false) -> void:
	if not preserve_cross_shards:
		cross.sample(-1.0)
	for projectile in get_tree().get_nodes_in_group("boss2_projectiles"):
		projectile.dissolve(shatter_ricochets and projectile.is_in_group("boss2_ricochets"))
	for beam in lasers:
		beam.present(beam.position.x,false,false,Rect2(),clock)

func fire_ricochet_volley(index: int) -> void:
	if phase != 3 or clock >= 70.40:
		return
	for i in range(-3,4):
		var live := get_tree().get_nodes_in_group("boss2_ricochets").filter(func(p): return p.dangerous)
		if live.size() >= RICOCHET_LIMIT:
			live[0].dissolve(false)
		var projectile := Projectile.instantiate()
		projectile.set_script(preload("res://scripts/boss2/ricochet.gd"))
		projectile.direction = Vector2.DOWN.rotated(i*0.30+(-0.12 if index%2 == 0 else 0.12))
		projectile.speed = 320
		projectile.bullet_color = Color("#15BFFF") if i%2 == 0 else Color("#FF299D")
		projectile.position = boss.position+Vector2(0,55)
		battle.add_child(projectile)

func fire(direction: Vector2, speed: float, tint: Color) -> void:
	# Phase guard prevents queued or manually invoked normal volleys in the cross.
	if phase in [0,3,4,6] or get_tree().get_nodes_in_group("boss2_projectiles").filter(func(p): return p.dangerous).size() >= PROJECTILE_LIMIT:
		return
	var projectile := Projectile.instantiate()
	projectile.direction = direction.normalized()
	projectile.speed = speed*(1.0+(difficulty_multiplier-1.0)*0.4)*normal_speed_multiplier
	projectile.bullet_color = tint
	projectile.position = boss.position+Vector2(0,55)
	battle.add_child(projectile)

func ring(count: int, speed: float, offset: float, tint: Color, gap: float = 0.27) -> void:
	var origin := boss.global_position+Vector2(0,55)
	var aim: float = (battle.player.hit_center()-origin).angle()
	var formation := preload("res://scripts/systems/combat_aim.gd")
	var visible := formation.visible_count(count)
	for i in range(visible):
		var angle := formation.lower_angle(i,visible,aim,offset)
		if absf(wrapf(angle-PI/2,-PI,PI)) >= gap:
			fire(Vector2.RIGHT.rotated(angle),speed,tint)

func attack(index: int) -> void:
	if phase not in [1,2,5]:
		return
	var hard := phase == 2
	var tint := Color("#20B9FF") if not hard else Color("#FF259C")
	var kind := index % 3
	var opening_growth := mini(3,int(maxf(0,clock-12.80)/8.0)) if phase == 1 else 0
	if kind == 0:
		ring(roundi((22 if hard else (12 if phase == 5 else 16 + opening_growth*2))*difficulty_multiplier),145 if hard else 115 + opening_growth*5,clock * 0.11,tint,0.27)
	elif kind == 1:
		# Successive symmetric rotating pairs form reusable circular spirals.
		for i in range(roundi((8 if hard else 5 + mini(2,opening_growth))*difficulty_multiplier)):
			var angle := clock * 0.6 + i * 0.23
			fire(Vector2.RIGHT.rotated(angle),150 if hard else 120,tint)
			fire(Vector2.LEFT.rotated(-angle),150 if hard else 120,tint)
	else:
		var origin := boss.position + Vector2(0,55)
		var aim: Vector2 = (battle.player.get_node("CollisionShape2D").position + battle.player.position - origin).normalized()
		var half := 2
		for i in range(-half,half+1):
			fire(aim.rotated(i * 0.14),155 if hard else 125,Color("#FF259C"))
