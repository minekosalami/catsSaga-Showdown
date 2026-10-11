extends SceneTree

var checks := 0
var failures := 0
var session: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func press(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func reveal_advance(dialogue: Node) -> void:
	if not dialogue.is_revealed():
		await press(KEY_Z)
	await press(KEY_Z)

func finish(dialogue: Node) -> void:
	while dialogue.active:
		await press(KEY_Z)

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-bart.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(session.saves.save_path + suffix)
	check(InputMap.action_get_events("ui_accept").size() == 1 and InputMap.action_get_events("ui_accept")[0].keycode == KEY_Z, "menu confirmation mapped exclusively to Z")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var start: Button = current_scene.menu_container.get_node("StartButton")
	start.grab_focus()
	for code in [KEY_E, KEY_ENTER, KEY_SPACE]:
		await press(code)
		check(current_scene.name == "Mainmenu" and not session.busy, "removed key cannot confirm menu: " + str(code))
	await press(KEY_DOWN)
	check(not start.has_focus(), "arrow keys navigate main menu")
	start.grab_focus()
	await press(KEY_Z)
	await create_timer(0.45).timeout
	check(current_scene.name == "Overworld", "Z confirms Start and enters overworld")
	await session.travel("bart_area", "FromDeep")
	var world: Node = current_scene
	world.player.position = Vector2(1000, 520)
	await process_frame
	await process_frame
	session.request_main_menu()
	await process_frame
	await process_frame
	var menu_position: Vector2 = world.player.position
	await press(KEY_DOWN)
	await create_timer(0.1).timeout
	check(world.player.position == menu_position and not world.interaction_indicator.visible, "confirmation menu blocks arrow movement and interaction")
	session.confirmation.canceled.emit()
	await process_frame
	var bart_position: Vector2 = world.map.get_node("Characters").get_child(0).position
	for code in [KEY_E, KEY_ENTER, KEY_SPACE]:
		await press(code)
		check(not world.dialogue.active, "removed key cannot interact: " + str(code))
	await press(KEY_Z)
	var d: Node = world.dialogue
	check(d.active and d.node_id == "BART_001" and d.text_label.visible_characters < d.text_label.get_total_character_count(), "Z starts opening with typewriter")
	for code in [KEY_E, KEY_ENTER, KEY_SPACE]:
		await press(code)
		check(d.node_id == "BART_001" and d.choices.is_empty(), "removed key cannot advance: " + str(code))
	await reveal_advance(d)
	check(d.choices.size() == 1 and d.choices[0].text == "What?", "What? response requires active selection")
	await press(KEY_Z)
	check(d.node_id == "BART_002" and d.line_index == 0 and d.choices.is_empty(), "one Z selects exactly one node without advancing next line")
	await reveal_advance(d)
	var position: Vector2 = world.player.position
	await press(KEY_DOWN)
	check(d.selected_choice == 1 and d.choice_buttons[1].has_focus(), "Down selects No with visible focus")
	await create_timer(0.1).timeout
	check(world.player.position == position, "choice arrows cannot move overworld player")
	await press(KEY_Z)
	check(not d.active and d.outcome == "declined" and not session.busy and not session.evil_bart_defeated, "No restores control without progression or battle")
	await press(KEY_Z)
	check(d.node_id == "BART_001", "declined introduction restarts from opening")
	await reveal_advance(d)
	await press(KEY_Z)
	await reveal_advance(d)
	await press(KEY_Z)
	check(d.node_id == "BART_003" and d.lines.size() == 3, "Yes enters three sequential Refraction entries")
	check(d.text_label.text.contains("[color=#B47AFF][b]The Refraction[/b][/color]"), "Refraction uses consistent purple bold")
	check(d.text_label.get_parsed_text() == "Are you familar with The Refraction? Well, probably not.", "exact supplied spelling and punctuation preserved")
	for index in range(3):
		check(d.line_index == index, "Refraction line requires separate advance " + str(index))
		await reveal_advance(d)
	check(d.choices.size() == 2 and d.choices[1].text == "What is Saturate?", "both ability responses available")
	check(d.choice_buttons[1].get_child(0).text.contains("[color=#FF6666]S[/color]"), "choice text uses same rainbow formatter")
	await press(KEY_DOWN)
	await press(KEY_Z)
	check(d.node_id == "BART_004B" and d.lines.size() == 3, "explanation branch has exactly three lines")
	check(d.text_label.text.contains("[color=#FFA94D]([/color]") and d.text_label.text.contains("[color=#FFE066])[/color]"), "both SATURATE parentheses are rainbow colored")
	check(d.text_label.get_parsed_text() == "SATURATE() is a strength not many have...", "rich text never exposes markup")
	for index in range(3):
		await reveal_advance(d)
	check(d.node_id == "BART_005" and not session.busy and current_scene == world, "explanation converges on warning without early fight")
	for entry in d.history:
		check(entry.formatted == load("res://scripts/world/dialogue_format.gd").format_text(entry.text), "history retains formatted original entry")
	# Check alternate branch through the same reusable renderer; avoid starting battle here.
	d._finish("declined")
	await press(KEY_Z)
	await reveal_advance(d)
	await press(KEY_Z)
	await reveal_advance(d)
	await press(KEY_Z)
	for index in range(3):
		await reveal_advance(d)
	await press(KEY_Z)
	check(d.node_id == "BART_004A" and d.lines[0].text == "Okay, great. But I just need to do one thing...", "Maybe branch uses exact one-line response")
	await reveal_advance(d)
	check(d.node_id == "BART_005", "Maybe converges on same final warning")
	await reveal_advance(d)
	check(session.busy and session.curtain.color == Color.WHITE and session.curtain.position.y < 0, "final warning starts descending solid white wipe")
	check(session.curtain.size.is_equal_approx(Vector2(1280, 720)), "white rectangle covers full window and side areas")
	check(world.player.movement_locked, "movement locked during wipe")
	await press(KEY_Z)
	await press(KEY_X)
	await scene_changed
	var host: Node = current_scene
	var game: Node = host.battle
	check(host.name == "CombatHost" and host.arena.size == Vector2i(540, 900), "wipe initializes original portrait battle")
	check(session.curtain.position.y == 0 and session.curtain.modulate.a > 0.95, "scene changes while entire window is white")
	check(game.process_mode == Node.PROCESS_MODE_DISABLED and not game.music_player.playing, "combat timing and music disabled during reveal")
	await press(KEY_Z)
	await press(KEY_X)
	check(not game.player.saturate_used and game.get_children().filter(func(child): return child.scene_file_path == "res://scenes/bullet.tscn").is_empty(), "combat firing and SATURATE ignored during reveal")
	await create_timer(0.4).timeout
	check(not session.busy and game.music_player.playing and game.elapsed_time < 0.3 and not game.boss_spawned, "music and combat start from zero after reveal")
	game.player.invincible = true
	game.music_player.seek(7)
	await create_timer(0.2).timeout
	check(game.boss_spawned and absf(game.boss.elapsed - game.music_player.get_playback_position()) < 0.15, "original spawn cue and boss music clock preserved")
	game.boss.take_damage(game.boss.health)
	await create_timer(1.35).timeout
	check(game.ui.victory_screen.visible and session.story_flags.get("bart_victory_dialogue_pending", false), "confirmed victory preserves animation and queues dialogue")
	check(session.story_flags.get("flooded_forest_key_obtained",false) and session.saves.read_save().story_flags.flooded_forest_key_obtained,"actual Bart victory awards and persists Flooded Forest Key")
	check(session.saves.read_save().story_flags.bart_victory_dialogue_pending, "pending victory dialogue saved before navigation")
	# Loading after a victory-screen interruption delivers the line without another fight.
	await session.load_game()
	await process_frame
	world = current_scene
	check(world.dialogue.active and world.dialogue.lines[0].text == "You were more powerful than I thought... You'll do great out there!", "load after confirmed victory delivers exact pending line")
	check(world.map.get_node("Characters").get_child(0).position == bart_position, "Bart remains in original location")
	await finish(world.dialogue)
	check(session.story_flags.get("bart_victory_dialogue_seen", false) and not session.story_flags.has("bart_victory_dialogue_pending"), "completed dialogue marks seen and clears pending")
	check(session.saves.read_save().story_flags.bart_victory_dialogue_seen, "completed flag autosaved")
	await session.load_game()
	await process_frame
	world = current_scene
	check(not world.dialogue.active and session.evil_bart_defeated, "completed victory dialogue does not repeat after load")
	for repeat in range(2):
		await press(KEY_Z)
		check(world.dialogue.lines[0].text == "See you soon... Maybe one day I'll be able to beat you.", "repeat interaction uses exact post-victory line")
		await finish(world.dialogue)
		check(current_scene == world and not session.busy, "repeat interaction never triggers battle")
	var legacy: Dictionary = session.saves.validate({"version": 1, "area": "bart_area", "position": [1000,520], "evil_bart_defeated": true, "story_flags": {"inspected_tree": true}})
	check(legacy.story_flags.bart_victory_dialogue_seen and legacy.story_flags.inspected_tree, "legacy defeated save respects progression and other flags")
	await session.new_game()
	check(not session.evil_bart_defeated and not session.story_flags.has("bart_victory_dialogue_seen"), "new game alone resets encounter progression")
	await session.travel("bart_area", "FromDeep")
	await session.begin_battle(Vector2(1000, 520))
	check(not session.story_flags.has("bart_victory_dialogue_pending"), "regular encounter does not queue victory dialogue")
	current_scene.battle.player.take_damage(3)
	await process_frame
	check(current_scene.battle.game_over and not session.evil_bart_defeated and not session.story_flags.has("bart_victory_dialogue_pending"), "loss cannot mark victory or queue its dialogue")
	await session.main_menu()
	check(not session.evil_bart_defeated and session.story_flags.is_empty(), "aborted or lost encounter leaves no victory flags")
	check(not session.story_flags.get("flooded_forest_key_obtained",false),"Bart defeat never awards Flooded Forest Key")
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("BART VALIDATION: ", checks, " checks, ", failures, " failures")
	# Allow the audio server to retire looping playback before test shutdown.
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
