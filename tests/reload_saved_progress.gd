# Run after headless_qol.gd using the same XDG_DATA_HOME.
extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	print("PASS: " + message if ok else "FAIL: " + message)
	if not ok:
		failures += 1

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var session := root.get_node("Session")
	session.saves.save_path = "user://validation-qol.json"
	check(not session.evil_bart_defeated, "new process begins without in-memory boss state")
	check(change_scene_to_file("res://scenes/main_menu.tscn") == OK, "fresh process starts main menu")
	await process_frame
	await process_frame
	check(not current_scene.menu_container.get_node("ContinueButton").disabled, "fresh process recognizes valid saved progress")
	current_scene.menu_container.get_node("ContinueButton").pressed.emit()
	await create_timer(0.45).timeout
	check(current_scene.name == "Overworld" and session.area_id == "bart_area", "Continue reloads saved area after process restart")
	check(session.evil_bart_defeated and session.story_flags.get("inspected_tree", false), "boss and story flags persist across processes")
	check(current_scene.player.position == Vector2(1000, 520), "saved position persists across processes")
	await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_Z
	event.pressed = false
	Input.parse_input_event(event)
	check(current_scene.dialogue.active and not current_scene.pending_battle, "saved victory prevents restarting Bart encounter")
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("RELOAD VALIDATION: ", failures, " failures")
	quit(0 if failures == 0 else 1)
