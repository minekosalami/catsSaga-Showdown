extends SceneTree
const Cfg = preload("res://scripts/incarna/config.gd")
const Art = preload("res://scripts/incarna/art.gd")
var failures := 0
var checks := 0
var session: Node
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func freeze(game: Node) -> void:
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.timeline.set_physics_process(false)
	game.music_player.stop()
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-incarna.json"
	await session.new_game()
	await session.travel("underground_cave","FromFlooded")
	var cave: Node = current_scene.map
	check(cave.boss.get_script() == load("res://scripts/incarna/rig.gd") and cave.boss.preview_mode,"cave uses actual connected Incarna art")
	check(not session.story_flags.get("incarna_defeated",false),"new game has no invented completion")
	session.encounter_id = "incarna"
	session.encounter_active = true
	session.return_position = preload("res://scripts/world/cave_layout.gd").SHORTCUT_JUNCTION+Vector2(0,160)
	session.transition_to("res://scenes/incarna/combat_host.tscn",true)
	var stages := {}
	while session.busy:
		await process_frame
		stages[session.battle_transition.stage] = true
		if current_scene != null and current_scene.has_method("record_victory") and session.busy:
			check(not current_scene.battle.music_player.playing and current_scene.battle.elapsed_time == 0,"no soundtrack or timeline under transition")
	check(stages.has("travel"),"existing star transition is used")
	var host: Node = current_scene
	var game: Node = host.battle
	check(host.arena.size == Cfg.SIZE and host.arena_container.scale == Vector2.ONE,"native widescreen arena")
	check(session.battle_transition.end_point.distance_to(Cfg.SPAWN) < .01,"star lands on actual wide battle spawn")
	check(game.music_player.stream.resource_path.ends_with("Malware - 006.mp3") and game.music_player.playing and game.music_player.pitch_scale == 1,"new soundtrack starts at normal rate")
	check(game.player.health == 3 and game.player.entrance_locked,"fresh Endure player locked for emergence")
	var spawn: Vector2 = game.player.hit_center()
	key(KEY_RIGHT,true)
	key(KEY_X,true)
	await create_timer(.12).timeout
	key(KEY_RIGHT,false)
	key(KEY_X,false)
	check(game.player.hit_center() == spawn and game.player.stamina == 1,"emergence blocks movement and sprint")
	freeze(game)
	for time in [0.0,2.0,5.0,9.99]:
		game.update_clock(time)
		check(game.player.entrance_locked and game.timeline.shots.is_empty() and game.rig.emergence < 1,"slow protected emergence at "+str(time))
	game.update_clock(10)
	check(not game.player.entrance_locked and is_equal_approx(game.rig.emergence,1),"emergence ends at ten seconds")
	for code in [KEY_Z,KEY_X]: key(code,true)
	key(KEY_Z,false)
	key(KEY_X,false)
	check(not game.player.saturate_used and not game.get_children().any(func(n: Node): return n.scene_file_path == "res://scenes/bullet.tscn"),"survival disables shooting and SATURATE")
	for letter in "CATA":
		key(letter.unicode_at(0),true)
		key(letter.unicode_at(0),false)
	check(game.player.invincible,"typed CATA remains functional")
	game.player.invincible = false
	key(KEY_RIGHT,true)
	game.player.position = Vector2(5000,-500)
	game.player._physics_process(.016)
	key(KEY_RIGHT,false)
	check(Cfg.PLAY_AREA.grow(-game.player.damage_hitbox_radius+.01).has_point(game.player.hit_center()),"damage center stays in lower play area")
	game.player.position = Cfg.SPAWN-game.player.get_node("CollisionShape2D").position
	host.record_victory()
	check(not session.story_flags.get("incarna_defeated",false),"manual record cannot win early")
	game.timeline.reset_clock(20.57)
	game.update_clock(20.57)
	check(game.timeline.barrages.size() == 1 and game.timeline.barrages[0].count == 10,"first drop telegraphs ten spears")
	check(game.timeline.shots.is_empty(),"warning has no projectile damage")
	for i in range(32):
		game.player.position.x = 280+i*12
		game.update_clock(20.57+i*.1)
	var fired: Array = game.timeline.fired_log.filter(func(s: Dictionary): return s.id == 0)
	check(fired.size() == 10,"ten spears launch")
	for i in range(1,fired.size()):
		check(is_equal_approx(fired[i].time-fired[i-1].time,.1),"exact 0.1-second spear spacing")
		check(fired[i].target.x > fired[i-1].target.x,"each spear snapshots moving player anew")
	for shot in game.timeline.shots:
		if shot.kind == "spear":
			var logged: Array = fired.filter(func(s: Dictionary): return s.time == shot.born)
			if not logged.is_empty(): check(shot.direction.is_equal_approx((logged[0].target-shot.origin).normalized()),"launch-time ballistic aim")
	game.timeline.reset_clock(41.14)
	game.update_clock(41.14)
	game.timeline.issue({"time":41.14,"kind":"paw","section":3,"index":0})
	game.timeline.issue({"time":41.14,"kind":"zone","section":3,"index":0})
	check(game.timeline.lunges.size() == 2 and game.timeline.zones.size() == 2,"connected paw strikes and random zones coexist")
	var target: Vector2 = game.timeline.lunges[0].target
	game.update_clock(41.14+Cfg.LUNGE_WARNING+Cfg.LUNGE_TRAVEL)
	check(game.rig.paw_tip(0).distance_to(target) < .01,"rendered paw reaches warning target")
	game.player.position = target-game.player.get_node("CollisionShape2D").position
	game.player.previous_hit_center = game.player.hit_center()
	game.player.invulnerability_timer = 0
	game.player.sprint_protection = 0
	var health: int = game.player.health
	game.timeline.collide()
	check(game.player.health == health-1,"paw contact damages player")
	game.timeline.collide()
	check(game.player.health == health-1,"shared grace prevents stacked damage")
	check(game.timeline.shots.any(func(s: Dictionary): return s.kind == "fragment"),"zones emit radial fragments")
	game.timeline.clear()
	game.timeline.damage_enabled = true
	for i in range(Cfg.MAX_SHOTS): game.timeline.fire(Vector2(400,400),Vector2.DOWN,200,"fragment",game.elapsed_time)
	check(game.timeline.shots.size() == Cfg.MAX_SHOTS-Cfg.SPEAR_RESERVE,"fragment cap reserves room for signature spears")
	for i in range(15): game.timeline.fire(Vector2(500,400),Vector2.DOWN,500,"spear",game.elapsed_time)
	check(game.timeline.shots.filter(func(s: Dictionary): return s.kind == "spear").size() == 15,"full fifteen-shot barrage survives dense pressure")
	game.timeline.clear()
	game.timeline.damage_enabled = true
	game.player.invulnerability_timer = 0
	game.player.sprint_protection = 0
	game.timeline.fire(game.player.hit_center()-Vector2(100,0),Vector2.RIGHT,500,"spear",game.elapsed_time)
	game.timeline.shots[0].point = game.player.hit_center()+Vector2(100,0)
	health = game.player.health
	game.timeline.collide()
	check(game.player.health == health-1,"actual spear sweep damages across a skipped position")
	game.player.health = 3
	for cue in [27.42,41.14,82.28,96.0,102.85]:
		game.timeline.reset_clock(cue-.01)
		game.update_clock(cue)
		check(game.timeline.section == Cfg.section_at(cue),"exact musical response at "+str(cue))
	game.timeline.reset_clock(82.28)
	game.update_clock(82.28)
	check(game.timeline.barrages[0].count == 15,"returning beat telegraphs fifteen spears")
	for part in game.rig.pieces.values(): check(part.texture == Art.SHEET,"every part uses original sheet")
	check(game.rig.cables.size() >= 7,"metal tethers connect creature")
	check(game.timeline.segments_distance(Vector2(-100,0),Vector2(100,0),Vector2(0,-20),Vector2(0,20)) == 0,"swept collision catches crossing")
	game.player.health = 3
	game.update_clock(Cfg.END-.001)
	check(not game.victory_started,"no early survival victory")
	game.update_clock(Cfg.END)
	game.update_clock(Cfg.END)
	check(game.victory_started and game.ui.result.visible and game.timeline.shots.is_empty(),"one clean ending clears hostiles")
	check(session.story_flags.get("incarna_defeated",false) and session.saves.read_save().story_flags.get("incarna_defeated",false),"victory persists with existing saves")
	await create_timer(.4).timeout
	check(not game.music_player.playing,"MP3 tail fades and stops")
	game.ui.return_button.pressed.emit()
	while session.busy: await process_frame
	check(current_scene.name == "Overworld" and current_scene.map.current_room == 8,"victory returns to cave junction")
	check(not current_scene.map.boss.visible,"completed boss cannot retrigger")
	await session.transition_to("res://scenes/incarna/combat_host.tscn",true)
	current_scene.battle.ui.retry_button.pressed.emit()
	while session.busy: await process_frame
	game = current_scene.battle
	check(game.player.health == 3 and game.elapsed_time < 1.0 and game.player.entrance_locked,"Retry resets health, music and emergence")
	freeze(game)
	game.update_clock(11)
	game.player.invulnerability_timer = 0
	game.player.take_damage(3)
	check(game.game_over and game.ui.result.visible and not game.ui.return_button.visible,"defeat offers retry/menu")
	game.ui.main_menu_button.pressed.emit()
	while session.busy: await process_frame
	check(current_scene.name == "Mainmenu","Main Menu works")
	print("INCARNA: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
