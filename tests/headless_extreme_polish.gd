extends SceneTree
const Plan = preload("res://scripts/journey/layout.gd")
var checks := 0
var failures := 0
var session: Node
func _initialize() -> void:
	create_timer(80).timeout.connect(func():quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures+=1;push_error("FAIL: "+message)
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_bullets"):bullet.queue_free()
	await process_frame
func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://extreme-polish.json"
	await session.new_game()
	for area in Plan.ORDER:
		await session.travel(area,"Start")
		var map: Node2D = current_scene.map
		for pair in [["Paths","TrailSurface"],["Water","WaterSurface"]]:
			var logical: TileMapLayer = map.get_node(pair[0])
			var surface: TileMapLayer = map.get_node(pair[1])
			check(surface.get_used_cells().size()==logical.get_used_cells().size()*4,area+" complete quarter-tile surface: "+pair[0])
			check(not logical.visible and surface.visible,area+" one visible terrain surface")
			check(surface.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and not surface.collision_enabled,area+" crisp surface shares logical collisions")
		check(map.get_node("Water").collision_enabled,area+" logical water remains solid")
		var bridge: TileMapLayer = map.get_node("Bridges")
		var expected := 0
		for rect: Rect2i in map.get_meta("bridge_rects"):
			expected += rect.size.x*rect.size.y
			for y in range(rect.position.y,rect.end.y):
				for x in range(rect.position.x,rect.end.x):check(bridge.get_cell_source_id(Vector2i(x,y))==0,"continuous rectangular deck")
		check(bridge.get_used_cells().size()==expected,area+" no staircase or stray boardwalk cells")
	await session.travel("flooded_forest","Start")
	# A valid pre-polish save may now stand in a repaired water footprint.
	check(session.save_current(),"current-format save can be written")
	var snapshot: Dictionary = session.saves.read_save()
	var flags: Dictionary = snapshot.story_flags.duplicate(true)
	var old_point := Vector2(1904,592)
	check(not current_scene.map.is_walkable_position(old_point),"migration probe is actual solid water")
	snapshot.position = [old_point.x,old_point.y]
	check(session.saves.write_save(snapshot) and await session.load_game(),"existing layout-revision save still loads")
	await physics_frame
	await physics_frame
	check(current_scene.map.is_walkable_position(current_scene.player.position) and current_scene.player.position!=old_point,"real collider validation relocates an obstructed old position safely")
	check(session.story_flags==flags,"safe relocation preserves progression flags exactly")
	var actor: Node2D = current_scene.player
	for rect: Rect2i in current_scene.map.get_meta("bridge_rects"):
		var start := Vector2(rect.position)*32+Vector2(-40,rect.size.y*16)
		check(current_scene.map.is_walkable_position(start),"bridge starts on actual dry bank")
		actor.position = start
		await physics_frame
		key(KEY_RIGHT,true)
		await create_timer((rect.size.x*32+80)/actor.speed+.35).timeout
		key(KEY_RIGHT,false)
		check(actor.position.x>rect.end.x*32+20,"actual player walks across bridge and both banks")
	await session.travel("entrance","Start")
	actor = current_scene.player
	var camera: Camera2D = actor.get_node("Camera2D")
	var body: Shape2D = actor.get_node("CollisionShape2D").shape
	key(KEY_LEFT,true)
	await create_timer(.08).timeout
	check(not actor.sprite.flip_h,"left key faces supplied left-facing artwork left")
	key(KEY_LEFT,false)
	await create_timer(.15).timeout
	check(not actor.sprite.flip_h,"standing preserves left-facing direction")
	key(KEY_RIGHT,true)
	await create_timer(.5).timeout
	check(actor.sprite.flip_h,"right key flips only the cat sprite")
	check(camera.lead.x>10 and camera.lead.length()<=camera.look_ahead+.01,"responsive bounded directional look-ahead")
	check(camera.global_position==camera.global_position.round(),"pixel-aligned exploration camera")
	check(actor.scale==Vector2.ONE and actor.rotation==0 and actor.get_node("CollisionShape2D").shape==body,"animation never mirrors or scales the physics body")
	key(KEY_RIGHT,false)
	var scale_before: Vector2 = actor.sprite.scale
	await create_timer(.7).timeout
	check(actor.sprite.flip_h,"standing preserves right-facing direction")
	check(actor.sprite.scale.distance_to(scale_before)>.00001,"existing cat has animated breathing / settling")
	check(actor.sprite.material.get_shader_parameter("pixel_size")==2.0,"cat uses two-display-pixel sampling without replacing its texture")
	await session.travel("bart_area","Start")
	await session.begin_battle(Vector2(1792,1000))
	var battle: Node = current_scene.battle
	battle.player.invincible = true
	battle.music_player.seek(21)
	await create_timer(.25).timeout
	var boss: Node = battle.boss
	check(is_instance_valid(boss) and boss.health==300,"Bart remains the original 300 HP boss")
	boss.set_process(false)
	await clear_bullets()
	boss.fire_gapped_ring(20,170,.3,Color.WHITE)
	check(not get_nodes_in_group("enemy_bullets").is_empty(),"redirected ring remains functional")
	for bullet in get_nodes_in_group("enemy_bullets"):check(bullet.direction.y>.05,"non-spiral ring enters the lower playfield")
	await clear_bullets()
	boss.fire_flower(28,185,6,.5,Color.WHITE)
	check(get_nodes_in_group("enemy_bullets").size()==17,"petal fan avoids doubling the former active half-ring density")
	for bullet in get_nodes_in_group("enemy_bullets"):
		check(bullet.direction.y>.05 and bullet.speed>=160 and bullet.speed<=210,"directed petals preserve speed modulation and lower-field travel")
	await clear_bullets()
	boss.spiral_remaining = 1
	boss.spiral_double = false
	boss.spiral_angle = -PI*.5
	boss.fire_spiral_step()
	check(get_nodes_in_group("enemy_bullets")[0].direction.y<-.99,"intentional upward spiral ray remains unchanged")
	await session.main_menu()
	session.encounter_id = "boss2"
	await session.transition_to("res://scenes/boss2/combat_host.tscn",true)
	battle = current_scene.battle
	battle.player.invincible = true
	battle.set_physics_process(false)
	battle.player.get_node("Sprite2D").flip_h = true
	battle.effects.afterimage(battle.player.get_node("Sprite2D"))
	check(battle.effects.ghosts[-1].flip_h and battle.effects.ghosts[-1].rotation==battle.player.get_node("Sprite2D").global_rotation,"sprint afterimages preserve the actual facing and animated pose")
	battle.timeline.phase = 1
	battle.timeline.ring(28,145,.3,Color.WHITE)
	var projectiles := get_nodes_in_group("boss2_projectiles")
	check(not projectiles.is_empty(),"Doppelcat's redirected ring still spawns")
	for bullet in projectiles:check(bullet.direction.y>.05,"Doppelcat's non-spiral ring faces playable field")
	check(battle.timeline.BOUNDARIES[-1]==140.8,"original survival requirement remains exact")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("EXTREME POLISH: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
