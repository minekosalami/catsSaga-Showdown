extends Node2D
# A read-only observer of the existing battle clock and signals. The combat
# controllers, projectiles, music, progression and physics never depend on it.
@export var look: Resource
@export_range(0.0,1.0,0.05) var effect_strength := 0.7
const SIZE := Vector2(540,900)
var battle: Node2D
var environment: Node2D
var atmosphere: ShaderMaterial
var title: Control
var clock := 0.0
var stage := 0.0
var pulse := 0.0
var motes: Array[Dictionary] = []
var impact := 0.0
var observed_boss: Node
var last_boss_health := -1.0
var last_player_health := 3
var boss_sprite: Sprite2D
var boss_offset := Vector2.ZERO
var boss_scale := Vector2.ONE
var boss_flash := 0.0
var boss_recoil := 0.0
var boss_attack := -1
var boss_phase := 1

func _ready() -> void:
	z_index = -9
	battle = get_parent()
	var old_background := battle.get_node_or_null("Background")
	if old_background == null:
		old_background = battle.get_node("Sprite2D")
	old_background.hide()
	environment = Node2D.new()
	environment.name = "EnvironmentalBase"
	environment.set_script(preload("res://scripts/ui/cinematic_environment.gd"))
	environment.look = look
	environment.show_behind_parent = true
	environment.visible = not battle.has_node("SurrealDirector")
	add_child(environment)
	var veil := ColorRect.new()
	veil.name = "Atmosphere"
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.size = SIZE
	veil.show_behind_parent = true
	veil.visible = not battle.has_node("SurrealDirector")
	add_child(veil)
	atmosphere = ShaderMaterial.new()
	atmosphere.shader = preload("res://shaders/cinematic_atmosphere.gdshader")
	veil.material = atmosphere
	atmosphere.set_shader_parameter("accent",look.accent)
	atmosphere.set_shader_parameter("secondary",look.secondary)
	atmosphere.set_shader_parameter("flooded",look.flooded)
	# Independent RNG avoids changing the random opening-enemy spawn sequence.
	var rng := RandomNumberGenerator.new()
	rng.seed = 82401 if look.flooded else 60189
	for i in range(36):
		motes.append({"origin":Vector2(rng.randf_range(12,528),rng.randf_range(0,900)),"speed":rng.randf_range(5,14),"life":rng.randf_range(4,9),"phase":rng.randf_range(0,9)})
	call_deferred("_attach_interface")

func _attach_interface() -> void:
	if not is_instance_valid(battle):
		return
	var ui_root: Control = battle.get_node("UI").get_child(0)
	title = Control.new()
	title.name = "CinematicIntroduction"
	title.set_script(preload("res://scripts/ui/cinematic_title.gd"))
	title.look = look
	ui_root.add_child(title)
	ui_root.move_child(title,mini(1,ui_root.get_child_count()-1))
	# Animate a visual sibling, never the collision shape or player transform.
	var player: Node = battle.get_node_or_null("Player")
	if player == null:
		player = battle.player
	var visuals := Node2D.new()
	visuals.name = "CinematicPlayerVisual"
	visuals.set_script(preload("res://scripts/ui/cinematic_player.gd"))
	visuals.accent = look.accent
	player.add_child(visuals)
	last_player_health = player.health
	player.health_changed.connect(_player_health_changed)
	update_clock(battle.elapsed_time)

func _player_health_changed(health: int) -> void:
	if health < last_player_health:
		impact = 1.0
	last_player_health = health

func _process(delta: float) -> void:
	impact = maxf(0,impact-delta/0.24)
	update_clock(battle.elapsed_time)
	var candidate = battle.boss if "boss" in battle else null
	if is_instance_valid(candidate) and candidate != observed_boss:
		observed_boss = candidate
		last_boss_health = candidate.health
		boss_sprite = candidate.get_node("Sprite2D")
		boss_offset = boss_sprite.offset
		boss_scale = candidate.sprite_resting_scale
		preload("res://scripts/ui/pixel_art.gd").apply(boss_sprite)
		boss_sprite.material.set_shader_parameter("display_size",boss_sprite.texture.get_size()*boss_scale)
		candidate.health_changed.connect(_boss_health_changed)
	if is_instance_valid(boss_sprite) and is_instance_valid(observed_boss) and not observed_boss.defeated_already:
		boss_flash = maxf(0,boss_flash-delta/0.12)
		boss_sprite.self_modulate = Color.WHITE.lerp(Color(1.65,1.35,1.45),0.0 if get_node("/root/GameSettings").values.flashing else boss_flash)
		if clock > 7.45:
			if observed_boss.attack_index!=boss_attack:
				boss_attack = observed_boss.attack_index
				boss_recoil = 1.0
			boss_recoil = maxf(0,boss_recoil-delta*8)
			var amount: float = .25 if get_node("/root/VisualSettings").reduced else get_node("/root/VisualSettings").motion
			var anticipate := 1-smoothstep(0,.18,observed_boss.shoot_timer)
			boss_sprite.offset = boss_offset+Vector2(0,(sin(clock*1.8)*2.5+boss_recoil*5-anticipate*2)*amount/maxf(boss_sprite.scale.y,0.001))
			boss_sprite.scale = boss_scale*Vector2(1+(pulse*.018+boss_recoil*.045)*amount,1-(pulse*.01+boss_recoil*.035)*amount)
			boss_sprite.rotation = sin(clock*1.1)*.025*amount

func _boss_health_changed(health: float, _maximum: int, _phase: int) -> void:
	if health < last_boss_health:
		impact = maxf(impact,0.32)
		boss_flash = 1.0
		preload("res://scripts/ui/battle_burst.gd").spawn(battle,observed_boss.global_position,look.accent,26)
	if _phase!=boss_phase:
		boss_phase = _phase
		preload("res://scripts/ui/battle_burst.gd").spawn(battle,observed_boss.global_position,look.accent,85)
	last_boss_health = health

func update_clock(playback: float) -> void:
	clock = playback
	stage = look.stage_at(clock)
	var beat := fposmod(clock,look.measure_seconds)
	pulse = (1-smoothstep(0.0,0.28,beat))*effect_strength
	environment.stage = stage*effect_strength
	environment.clock = clock
	var scenery: Sprite2D = battle.get_node("Background" if look.flooded else "Sprite2D")
	environment.position = (scenery.position-Vector2(270,450)).limit_length(3)
	environment.update_tone()
	atmosphere.set_shader_parameter("clock",clock)
	atmosphere.set_shader_parameter("stage",stage)
	atmosphere.set_shader_parameter("pulse",pulse)
	atmosphere.set_shader_parameter("effect_strength",effect_strength)
	if is_instance_valid(title):
		title.update_clock(clock)
		if battle.game_over or battle.victory_started:
			title.hide()
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(battle) and battle.has_node("SurrealDirector"): return
	if look == null:
		return
	# Drawn on the same background canvas, below every gameplay object.
	var tint := Color(look.accent,(0.13+stage*0.25+pulse*0.10)*effect_strength)
	draw_rect(Rect2(4,4,532,892),Color(look.accent,(0.2+stage*0.25+impact*0.2)*effect_strength),false,1,true)
	var center := Vector2(270,237)
	var turn := clock*0.028
	for ring in range(3):
		var radius := 95.0+ring*37.0+sin(clock*0.3+ring)*2
		if look.angular:
			var vertices := PackedVector2Array()
			for i in range(5):
				vertices.append(center+Vector2.RIGHT.rotated(turn*(1 if ring%2 == 0 else -1)+PI/4+i*TAU/4)*radius)
			draw_polyline(vertices,Color(tint,tint.a*(0.2+stage*0.7)),1,true)
		else:
			for arc in range(3):
				draw_arc(center,radius,turn+arc*TAU/3,turn+arc*TAU/3+PI*0.45,48,Color(tint,tint.a*(0.2+stage*0.7)),1,true)
	# Dim perspective/angular marks or water-like ellipses deepen the lower
	# backdrop. They are thin, low contrast and entirely behind the playfield.
	var floor_tint := Color(look.secondary,stage*0.055*effect_strength)
	for band in range(5):
		var y := 390.0+band*100+sin(clock*0.13+band)*6
		if look.angular:
			draw_line(Vector2(18,y),Vector2(522,y+12*sin(clock*0.11)),floor_tint,1,true)
		else:
			draw_set_transform(Vector2(270,y),0,Vector2(1,0.22))
			draw_arc(Vector2.ZERO,220.0+band*8,clock*0.03,clock*0.03+TAU*0.82,64,floor_tint,1,true)
			draw_set_transform(Vector2.ZERO)
	if look.angular:
		for i in range(7):
			draw_line(Vector2(270,370),Vector2(-160+i*145,900),floor_tint,1,true)
	for i in range(12):
		var angle := i*TAU/12+turn
		var from := center+Vector2.RIGHT.rotated(angle)*(188+sin(clock+i)*3)
		draw_line(from,from+Vector2.RIGHT.rotated(angle)*8,Color(tint,tint.a*stage*0.6),1,true)
	# Faint, thin falling embers/rising glimmers have no opaque circular cores.
	for mote in motes:
		var age := fposmod(clock+mote.phase,mote.life)
		var fade := sin(PI*age/mote.life)
		var point: Vector2 = mote.origin+Vector2(sin(clock*0.3+mote.phase)*12,-age*mote.speed)
		point.y = fposmod(point.y,900)
		draw_line(point,point+Vector2(0,2+stage*2),Color(look.accent,fade*0.16*effect_strength),1,true)
	# Corners gain energy during phase evolution, with no full-screen flashes.
	for corner in [Vector2(8,8),Vector2(532,8),Vector2(8,892),Vector2(532,892)]:
		var sign_x := 1 if corner.x < 270 else -1
		var sign_y := 1 if corner.y < 450 else -1
		draw_line(corner,corner+Vector2(sign_x*(16+stage*20+pulse*5),0),tint,2,true)
		draw_line(corner,corner+Vector2(0,sign_y*(16+stage*20+pulse*5)),tint,2,true)
