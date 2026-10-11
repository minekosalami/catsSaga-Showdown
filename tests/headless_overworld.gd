extends SceneTree

var failures: int = 0
var checks: int = 0
var session: Node

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func press(code: Key) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _initialize() -> void:
	create_timer(50.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func finish_dialogue(dialogue: Node) -> void:
	while dialogue.active:
		await press(KEY_Z)

func run() -> void:
	var save_manager = root.get_node("Session").saves
	save_manager.save_path = "user://validation-headless_overworld.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_manager.save_path + suffix):
			DirAccess.remove_absolute(save_manager.save_path + suffix)
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "project base resolution is 1280x720")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items" and ProjectSettings.get_setting("display/window/stretch/aspect", "keep") == "keep", "window stretching preserves aspect ratio")
	for filename in ["forest_entrance", "deep_forest", "bart_area", "player", "dialogue", "overworld"]:
		var packed := load("res://scenes/world/" + filename + ".tscn") as PackedScene
		check(packed != null and packed.can_instantiate(), filename + " scene loads")
	await session.new_game()
	var world: Node = current_scene
	check(world.name == "Overworld" and session.area_id == "entrance", "new game starts in Forest Entrance")
	check(world.player.position == Vector2(280, 450), "entrance start marker is honored")
	check(get_nodes_in_group("combat_music").is_empty(), "overworld has no continuous soundtrack")
	check(world.map.get_node("Characters").get_child_count() == 1, "entrance has one inspectable placeholder")
	var player: CharacterBody2D = world.player
	var camera: Camera2D = player.get_node("Camera2D")
	check(camera.enabled and camera.limit_right == 3200 and camera.limit_bottom == 1824, "player-follow camera uses map boundaries")
	var start := player.position
	key(KEY_D, true)
	await create_timer(0.5).timeout
	key(KEY_D, false)
	check(player.position.x > start.x + 90, "overworld keyboard movement works")
	key(KEY_D, true)
	key(KEY_S, true)
	await create_timer(0.25).timeout
	check(absf(player.velocity.length() - player.speed) < 0.1, "diagonal movement is normalized")
	key(KEY_D, false)
	key(KEY_S, false)
	# Probe a real StaticBody2D obstacle using the player collision shape.
	player.position = Vector2(405, 268)
	player.velocity = Vector2.ZERO
	key(KEY_D, true)
	await create_timer(0.9).timeout
	key(KEY_D, false)
	check(player.position.x < 431 and player.get_slide_collision_count() > 0, "tree trunk blocks overworld movement")
	player.position = Vector2(55, 450)
	player.velocity = Vector2.ZERO
	key(KEY_LEFT, true)
	await create_timer(0.35).timeout
	key(KEY_LEFT, false)
	check(player.position.x >= 43, "outer collision boundaries contain the player")
	# Real Area2D detection, not a direct travel callback.
	player.position = world.map.get_node("Portals/Exit0").position
	player.velocity = Vector2.ZERO
	await create_timer(0.9).timeout
	world = current_scene
	check(session.area_id == "deep_forest" and world.map.display_name == "Deep Forest", "entrance portal transitions to Deep Forest")
	check(world.player.position == world.map.get_node("Entries/FromEntrance").position, "arrival marker avoids immediate portal bounce")
	check(world.map.map_size == Vector2(5120, 2880), "Deep Forest is larger than entrance")
	check(world.map.get_node("Characters").has_node("ForestNPC") and world.map.get_node("Characters").has_node("FloodedGate"), "Deep Forest preserves its NPC and adds the Flooded Forest gate")
	var npc: Node2D = world.map.get_node("Characters/ForestNPC")
	world.player.position = npc.position + Vector2(0, 60)
	await process_frame
	await process_frame
	await press(KEY_Z)
	check(world.dialogue.active and world.player.movement_locked, "Z starts nearby NPC dialogue and locks movement")
	check(world.dialogue.speaker_label.text.contains("NPC"), "dialogue shows speaker")
	check(world.dialogue.text_label.visible_characters < world.dialogue.text_label.get_total_character_count(), "dialogue begins with typewriter reveal")
	var conversation_position: Vector2 = world.player.position
	key(KEY_D, true)
	await create_timer(0.1).timeout
	key(KEY_D, false)
	check(world.player.position == conversation_position, "movement stays disabled during conversation")
	await press(KEY_Z)
	check(world.dialogue.is_revealed(), "Z instantly reveals current dialogue line")
	await press(KEY_Z)
	check(world.dialogue.line_index == 1 and world.dialogue.active, "Z advances to next line")
	await finish_dialogue(world.dialogue)
	check(not world.dialogue.active and not world.player.movement_locked, "conversation finishes and restores movement")
	world.player.position = world.map.get_node("Portals/Exit0").position
	await create_timer(0.9).timeout
	check(session.area_id == "entrance" and current_scene.player.position == current_scene.map.get_node("Entries/FromDeep").position, "reverse forest portal restores correct entry marker")
	current_scene.player.position = current_scene.map.get_node("Portals/Exit0").position
	await create_timer(0.9).timeout
	world = current_scene
	world.player.position = world.map.get_node("Portals/Exit1").position
	await create_timer(0.9).timeout
	world = current_scene
	check(session.area_id == "bart_area", "Deep Forest connects to Evil Bart area")
	check(world.map.get_node("Characters").get_child_count() == 1, "Bart area contains only its encounter")
	world.player.position = Vector2(1000, 520)
	await process_frame
	await process_frame
	var before_battle: Vector2 = world.player.position
	await press(KEY_Z)
	check(world.dialogue.active and not world.pending_battle, "Bart interaction starts dialogue before battle")
	check(current_scene.name == "Overworld", "battle does not start before dialogue finishes")
	await finish_dialogue(world.dialogue)
	await create_timer(0.95).timeout
	var host: Node = current_scene
	check(host.name == "CombatHost" and session.encounter_active, "completed Bart conversation loads combat host")
	check(host.arena.size == Vector2i(540, 900) and host.arena_container.scale == Vector2(0.8, 0.8), "battle retains portrait coordinates and uniform scale")
	check(host.arena_container.position == Vector2(424, 0), "battle centers in 1280x720")
	check(host.arena.world_2d != root.world_2d, "combat uses an isolated physics world")
	var game: Node = host.battle
	check(game.player.get_viewport() == host.arena, "combat player belongs to fixed viewport")
	check(game.music_player.playing and get_nodes_in_group("combat_music").size() == 1, "one original combat soundtrack plays")
	game.player.invincible = true
	game.music_player.seek(7.0)
	await create_timer(0.2).timeout
	check(game.boss_spawned, "existing music cue spawns boss inside combat host")
	game.boss.fire_ring(3, 0.0, 0.0, Color.WHITE)
	for projectile in get_nodes_in_group("enemy_bullets"):
		check(projectile.get_viewport() == host.arena and projectile.get_parent() == game, "enemy projectile stays inside original arena")
	game.boss.take_damage(game.boss.health)
	await create_timer(1.35).timeout
	check(session.evil_bart_defeated and game.ui.victory_screen.visible, "victory animation records encounter completion")
	check(game.ui.victory_continue.visible and game.ui.victory_continue.has_focus(), "encounter victory offers focused return-to-forest button")
	check(not game.music_player.playing, "victory finishes music fade before return")
	game.ui.victory_continue.pressed.emit()
	game.ui.victory_continue.pressed.emit()
	while session.busy: await process_frame
	world = current_scene
	check(world.name == "Overworld" and session.area_id == "bart_area", "victory returns to Evil Bart area")
	check(world.player.position.is_equal_approx(before_battle), "return restores exact pre-battle player position")
	check(not session.encounter_active and session.evil_bart_defeated, "defeat record persists after leaving combat")
	check(get_nodes_in_group("combat_music").is_empty(), "combat soundtrack is removed before restoring overworld theme")
	await process_frame
	check(world.dialogue.active and world.dialogue.lines[0].text.begins_with("You were more powerful"), "return shows one-time victory dialogue")
	await finish_dialogue(world.dialogue)
	await press(KEY_Z)
	check(world.dialogue.active and not world.pending_battle, "defeated Bart uses alternate dialogue without re-triggering battle")
	check(world.dialogue.lines[0]["text"] == "See you soon... Maybe one day I'll be able to beat you.", "post-victory conversation is different")
	await finish_dialogue(world.dialogue)
	await create_timer(0.4).timeout
	check(current_scene.name == "Overworld", "post-victory dialogue stays in forest")
	await session.travel("deep_forest", "FromBart")
	check(session.evil_bart_defeated, "boss state survives area travel")
	session.travel("entrance", "FromDeep")
	session.travel("bart_area", "FromDeep")
	while session.busy: await process_frame
	check(session.area_id == "entrance", "duplicate transitions are rejected")
	session.main_menu()
	await scene_changed
	current_scene._start_game()
	check(session.busy and not current_scene.transitioning, "Start ignores activation during incoming menu fade")
	await create_timer(0.25).timeout
	check(current_scene.name == "Mainmenu", "world Main Menu navigation works")
	await session.new_game()
	check(not session.evil_bart_defeated and session.area_id == "entrance", "new playthrough resets encounter state")
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("OVERWORLD VALIDATION: ", checks, " checks, ", failures, " failures")
	# Allow the audio server to retire looping playback before test shutdown.
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
