extends SceneTree
const Layout = preload("res://scripts/maps/world_layout.gd")
const Journey = preload("res://scripts/journey/layout.gd")
var session: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(1)
		return
	create_timer(120).timeout.connect(func(): push_error("Removal regression timeout"); quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func ready_world() -> void:
	await settle()
	while current_scene.checking_spawn or not current_scene.encounters.loaded:
		await process_frame
	current_scene.encounters.set_process(false)
	session.forest_encounters.protection_until = INF

func tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func finish_lines(world: Node) -> void:
	for i in 30:
		if not world.dialogue.active or not world.dialogue.choices.is_empty(): return
		world.dialogue.advance()

func run() -> void:
	session = root.get_node("Session")
	await session.new_game(3)
	await ready_world()
	check(current_scene.player.position == Journey.SPAWNS.entrance, "original starting position")
	session.story_flags["smoki_interacted"] = true
	session.story_flags["blankkitten_defeated"] = true
	session.story_progress.necoins = 75
	session.story_progress.accept_cupid()
	session.story_progress.collect_feather("entrance_white")
	session.rpg.total_exp = 125
	session.exploration.reveal("entrance", Journey.SPAWNS.entrance)
	var forest: Dictionary = session.snapshot("entrance", Journey.SPAWNS.entrance)
	check(not forest.is_empty() and session.saves.validate(forest) == forest, "Forest save validation remains stable")
	var removed: Dictionary = session.saves.REMOVED_AREA_SIZES
	for area in removed:
		check(not session.playable_area(area) and not Layout.all_regions().has(area), area+" is not a playable or mapped destination")
		check(not FileAccess.file_exists("res://scenes/wonderland/"+area+".tscn"), area+" scene is deleted")
		var old := forest.duplicate(true)
		old.area = area
		old.position = [640, 480]
		old.checkpoint = {"area":area, "position":[640,480]}
		old.story_flags["wonderland_arrived"] = true
		var bits := PackedByteArray()
		var size: Vector2 = removed[area]/64.0
		bits.resize(ceili(size.x*size.y/8.0))
		bits.fill(255)
		old.exploration[area] = Marshalls.raw_to_base64(bits)
		var original := old.duplicate(true)
		var clean: Dictionary = session.saves.validate(old)
		if clean.is_empty():
			check(false, area+" save migration rejected a valid fixture")
			quit(1); return
		check(not clean.is_empty() and clean.area == "flooded_forest" and Vector2(clean.position[0],clean.position[1]) == Journey.SPAWNS.flooded_forest, area+" recovers to valid Forest spawn")
		check(clean.checkpoint.area == "flooded_forest" and clean.story_progress == forest.story_progress and clean.rpg == forest.rpg, area+" repairs checkpoint without losing progress")
		check(clean.exploration.entrance == forest.exploration.entrance and not clean.exploration.has(area), area+" preserves Forest fog")
		check(old == original, "validation does not mutate the source save")
		var path := "user://removed-region-fixture.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(old)); file.close()
		var before := FileAccess.get_sha256(path)
		check(JSON.stringify(session.saves.read_file(path)) == JSON.stringify(clean) and FileAccess.get_sha256(path) == before, area+" disk read recovers without rewriting original")
	# Exercise Continue with an actual old interior save and checkpoint.
	var old := forest.duplicate(true)
	old.area = "teapot_house"; old.position = [640,480]
	old.checkpoint = {"area":"throne_room", "position":[640,480]}
	var file := FileAccess.open(session.saves.progress_path(3), FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	check(await session.load_game(3), "Continue loads a removed-interior save")
	await ready_world()
	check(session.area_id == "flooded_forest" and not current_scene.player.movement_locked, "recovered save permits movement")
	check(session.story_progress.snapshot() == forest.story_progress and session.rpg.total_exp == 125, "Continue retains currency, quest, feather and RPG progress")
	await session.travel("wonderland_forest", "FromFlooded")
	check(session.area_id == "flooded_forest" and not session.busy, "removed destination is rejected without locking movement")
	# Real NPC interaction, battle entry, music-clock completion, return and repeat dialogue.
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	var world: Node = current_scene
	var npc: Node2D = world.map.get_node("Characters/Boss2NPC")
	var npc_position := npc.position
	world.player.position = npc.position+Vector2(0,65)
	await settle()
	await tap(KEY_Z)
	check(world.dialogue.active and world.pending_encounter == "boss2", "Z opens existing Doppelcat encounter")
	finish_lines(world)
	check(world.dialogue.choices.size() == 2, "existing Doppelcat choices")
	world.dialogue._choose(1)
	while session.busy: await process_frame
	check(session.encounter_id == "boss2" and current_scene.has_method("record_victory"), "Doppelcat battle entry remains functional")
	var host: Node = current_scene
	var battle: Node = host.battle
	battle.player.invincible = true
	check(battle.music_player.playing and host.arena.size == Vector2i(540,900), "original soundtrack and battle viewport")
	battle.music_player.seek(13)
	await create_timer(.25).timeout
	check(battle.timeline.phase == 1 and not get_nodes_in_group("enemy_bullets").is_empty(), "Doppelcat music-synchronized attacks run")
	battle.music_player.seek(battle.end_time)
	await create_timer(1.1).timeout
	check(battle.victory_started and session.story_flags.get("boss2_defeated",false), "existing survival ending records victory")
	host.rpg_ui.close_results()
	host.return_to_forest()
	while session.busy: await process_frame
	await ready_world()
	world = current_scene
	check(world.dialogue.active, "original post-victory dialogue remains")
	finish_lines(world)
	await settle()
	check(not world.player.movement_locked and session.area_id == "flooded_forest", "Doppelcat victory returns free exploration")
	check(world.map.get_node("Characters/Boss2NPC").position == npc_position, "Doppelcat remains at original position")
	for point in [Vector2(2660,1185), Vector2(3072,208)]:
		world.player.position = point
		await create_timer(.3).timeout
		check(not session.busy and not world.dialogue.active and world.find_child("AmbushTrap",true,false) == null, "former trap/door coordinates cannot trigger continuation")
	world.player.position = npc_position+Vector2(0,65)
	await settle(); await tap(KEY_Z)
	check(world.dialogue.lines[0].text == "You're not telling anyone about this", "later Doppelcat interaction retains original post-fight dialogue")
	finish_lines(world); await settle()
	check(not session.encounter_active and not session.busy, "repeat interaction never starts a rematch")
	var star: Node2D
	for item in get_nodes_in_group("interactables"):
		if item.has_meta("save_statue"): star = item; break
	world.player.position = star.position+Vector2(0,58)
	await settle(); await tap(KEY_Z)
	check(session.save_point_active, "Z opens existing manual save interaction")
	session.confirmation.confirmed.emit()
	await process_frame
	check(not session.saves.read_slot(3).is_empty(), "manual save still works after victory")
	check(await session.load_game(3), "victory save reloads")
	await ready_world()
	check(session.story_flags.get("boss2_defeated",false) and current_scene.find_child("AmbushTrap",true,false) == null, "defeated save cannot respawn the ambush")
	await session.main_menu()
	print("WONDERLAND REMOVAL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
