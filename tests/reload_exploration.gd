extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cartography.json"
	var saved: Dictionary = session.saves.read_save()
	if saved.is_empty() or not await session.load_game():
		push_error("Missing or invalid cartography test save")
		quit(1)
		return
	await process_frame
	await process_frame
	await physics_frame
	var ok: bool = session.exploration.snapshot() == saved.exploration and not session.map_reveal_cheat and current_scene.map_ui.minimap.visible
	print("RESTART EXPLORATION VALIDATION: ","PASS" if ok else "FAIL")
	current_scene.queue_free()
	await create_timer(0.2).timeout
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	quit(0 if ok else 1)
