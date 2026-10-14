extends SceneTree
var failures := 0
var checks := 0
var capture := false
var output := "/workspace/.catsSaga-validation/battle-entry"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func probe(path: String, identifier: String, from_world: bool = true) -> void:
	print("Checking entry: ", identifier, " world=", from_world)
	var session: Node = root.get_node("Session")
	if from_world: await session.new_game()
	var before: Node = current_scene
	var source: Sprite2D = session.battle_transition.sprite_for(before)
	var expected_start := Vector2.ZERO
	if source != null:
		if from_world:
			var camera: Camera2D = before.player.get_node("Camera2D")
			camera.zoom = Vector2.ONE * 0.8
			camera.position_smoothing_enabled = false
			camera.force_update_scroll()
			await process_frame
		expected_start = source.get_global_transform_with_canvas() * source.offset
	var point: Vector2 = before.player.global_position if from_world else Vector2.ZERO
	session.encounter_active = true
	session.encounter_id = identifier
	var overlay: Control = session.battle_transition
	var started := Time.get_ticks_msec()
	session.transition_to(path, true)
	check(session.busy and session.battle_entry_pending, identifier + " immediately locks entry")
	check(not await session.transition_to(path, true), "duplicate entry rejected")
	if source != null:
		check(overlay.start_point.distance_to(expected_start) < 0.01, "camera-transformed start is exact")
		check(not source.is_visible_in_tree(), "source cat safely replaced by one overlay sprite")
	var seen := {}
	var stages := {}
	var completion := {"ticks": 0}
	var on_stage := func(value: String):
		stages[value] = true
		if value == "idle": completion.ticks = Time.get_ticks_msec()
	overlay.stage_changed.connect(on_stage)
	var frozen_position := Vector2.ZERO
	var expected_end := Vector2.ZERO
	var frame_count := 0
	key(KEY_RIGHT, true)
	key(KEY_Z, true)
	key(KEY_X, true)
	key(KEY_SHIFT, true)
	while session.busy:
		await process_frame
		if not session.busy: break
		frame_count += 1
		if is_instance_valid(before) and from_world:
			check(before.player.global_position == point, "overworld stationary during entry")
		check(not session.can_pause() and not session.developer_menu.opened, "modal/gameplay input blocked")
		if current_scene != null and current_scene != before and current_scene.has_method("finish_entry"):
			var battle: Node = current_scene.battle
			if session.busy:
				check(not battle.music_player.playing and battle.music_player.get_playback_position() == 0, "music never starts under curtain")
				if "elapsed_time" in battle: check(battle.elapsed_time == 0, "audio timeline remains at zero")
				check(not battle.can_process() and not battle.player.can_process(), "battle physics and input frozen")
				if frozen_position == Vector2.ZERO:
					frozen_position = battle.player.position
					var sprite: Sprite2D = overlay.sprite_for(current_scene)
					var local_point: Vector2 = sprite.position + sprite.transform.basis_xform(sprite.offset) if sprite != null else Vector2.ZERO
					expected_end = current_scene.arena_container.position + (frozen_position + local_point) * current_scene.arena_container.scale
				check(battle.player.position == frozen_position, "battle spawn never moves during entry")
		if overlay.stage == "travel":
			check(overlay.background.modulate.a == 1 and not overlay.cat.visible and overlay.star.visible, "travel is star alone against opaque black")
		if not seen.has(overlay.stage):
			seen[overlay.stage] = true
			if overlay.stage in ["star_flash", "cat_return"]:
				check(overlay.star.position.distance_to(overlay.end_point) < 0.01, "star reaches exact destination")
			if overlay.stage == "cat_return":
				check(overlay.cat.position + overlay.cat.transform.basis_xform(overlay.cat.offset) == overlay.end_point, "cat reappears at star endpoint")
			if capture and identifier == "bart" and overlay.stage in ["blackout", "cat_flash", "travel", "cat_return", "reveal"]:
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute(output)
				var image := root.get_texture().get_image()
				image.save_png(output + "/" + overlay.stage + ".png")
				if overlay.stage in ["cat_flash", "cat_return"]:
					var center: Vector2 = overlay.start_point if overlay.stage == "cat_flash" else overlay.end_point
					var white_pixels := 0
					for y in range(int(center.y)-48,int(center.y)+48,2):
						for x in range(int(center.x)-48,int(center.x)+48,2):
							if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(Vector2i(x,y)): continue
							var pixel := image.get_pixel(x,y)
							if pixel.r > 0.95 and pixel.g > 0.95 and pixel.b > 0.95: white_pixels += 1
					check(white_pixels > 3, "cat flash renders bright white")
				if overlay.stage == "travel":
					for sample in [Vector2i(20,20), Vector2i(1250,20), Vector2i(20,690), Vector2i(1250,690)]:
						check(image.get_pixelv(sample).v < 0.001, "rendered background is solid black")
	key(KEY_RIGHT, false)
	key(KEY_Z, false)
	key(KEY_X, false)
	key(KEY_SHIFT, false)
	check(Time.get_ticks_msec() - started < 2200, "entry remains brief including local load")
	for stage in ["freeze", "blackout", "cat_flash", "loading", "travel", "star_flash", "cat_return", "reveal"]:
		# Loading may complete synchronously between frames; capture is verified separately.
		if stage not in ["freeze", "loading"]: check(stages.has(stage), "observed stage " + stage)
	overlay.stage_changed.disconnect(on_stage)
	var host: Node = current_scene
	var player: Node2D = host.battle.player
	check(overlay.end_point.distance_to(expected_end) < 0.01, "destination matches actual centered portrait viewport spawn")
	check(not overlay.visible and not session.battle_entry_pending and session.suspended_modes.is_empty(), "entry releases overlay and all process states")
	# GPU readback/PNG encoding can delay this probe after music has started.
	var since_reveal := float(Time.get_ticks_msec() - completion.ticks) / 1000.0
	check(host.battle.music_player.playing and host.battle.music_player.get_playback_position() <= since_reveal + 0.1, "soundtrack starts at original zero after reveal")
	check(player.can_process(), "player controls restored")
	if "health" in player: check(player.health == (5 if identifier == "blankkitten" else 3), "fresh battle restores health")
	check(overlay.star.get_script() == load("res://scripts/blankkitten/star.gd"), "existing star renderer reused")
	for sound in overlay.sounds:
		check(sound.stream is AudioStreamWAV and sound.pitch_scale == 1 and not sound.playing, "original isolated synthesized cue cleaned up")
	if identifier == "bart":
		host.battle.player.invincible = true
		host.battle.music_player.seek(7)
		await create_timer(0.15).timeout
		check(host.battle.boss_spawned and host.battle.boss.health == 300, "original music cue still spawns Bart")

func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-battle-entry-render.json" if capture else "user://validation-battle-entry.json"
	await probe("res://scenes/combat_host.tscn", "bart")
	await probe("res://scenes/boss2/combat_host.tscn", "boss2")
	await probe("res://scenes/blankkitten/combat_host.tscn", "blankkitten")
	await probe("res://scenes/blankkitten/combat_host.tscn", "blankkitten", false)
	await probe("res://scenes/incarna/combat_host.tscn", "incarna")
	await session.new_game()
	var previous: Node = current_scene
	var sprite: Sprite2D = previous.player.sprite
	check(not await session.transition_to("res://scenes/missing-battle.tscn", true), "failed load reports failure")
	check(current_scene == previous and sprite.visible and previous.player.can_process() and not session.busy and not session.battle_transition.visible, "failed load restores source, controls and screen")
	check(session.saves.read_save().area == "entrance", "entry/failure does not alter saved progression")
	# Flush the failed entry's deferred completion before awaiting the next entry.
	await create_timer(0.05, true, true, true).timeout
	print("Checking external interruption")
	var interrupt := func(value: String):
		if value == "travel": call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
	session.battle_transition.stage_changed.connect(interrupt)
	check(not await session.transition_to("res://scenes/combat_host.tscn", true), "interrupted entry reports failure")
	session.battle_transition.stage_changed.disconnect(interrupt)
	check(current_scene.name == "Mainmenu", "external scene interruption succeeds")
	check(not session.battle_transition.visible and session.suspended_modes.is_empty() and not session.battle_entry_pending and not session.encounter_active, "interrupted entry releases all locks and overlay")
	await session.main_menu()
	check(current_scene.name == "Mainmenu", "ordinary menu transition unchanged")
	print("Battle entry validation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
