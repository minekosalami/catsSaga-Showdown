extends SceneTree
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	run.call_deferred()
func run() -> void:
	await create_timer(.35).timeout
	var settings: Node=root.get_node("GameSettings")
	var ok: bool=settings.values.zoom==.8 and settings.values.master==.8 and not settings.values.shake and settings.binding_label("attack")=="Q" and root.get_node("VisualSettings").reduced and root.get_node("VisualSettings").motion==.4
	ok=ok and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size()==Vector2i(960,540)
	print("RESTART PERSISTENCE ","PASS" if ok else "FAIL",": ",settings.values)
	quit(0 if ok else 1)
