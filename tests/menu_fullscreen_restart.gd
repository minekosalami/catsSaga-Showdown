extends SceneTree
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	run.call_deferred()
func run() -> void:
	var settings: Node=root.get_node("GameSettings")
	if "--write" in OS.get_cmdline_user_args():
		settings.preview_display(1,Vector2i(1280,720))
		await create_timer(.2).timeout
		settings.confirm_display()
		print("FULLSCREEN SAVED ",settings.values.display_mode)
		quit(0 if settings.values.display_mode==1 else 1)
	else:
		await create_timer(.35).timeout
		print("FULLSCREEN actual mode ",DisplayServer.window_get_mode()," preference ",settings.values.display_mode)
		var ok: bool = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN and settings.values.display_mode==1
		print("FULLSCREEN RESTART ","PASS" if ok else "FAIL")
		quit(0 if ok else 1)
