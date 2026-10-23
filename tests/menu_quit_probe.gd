extends SceneTree
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	run.call_deferred()
func run() -> void:
	await root.get_node("Session").main_menu()
	print("Activating the actual Quit button")
	current_scene.menu_container.get_node("QuitButton").pressed.emit()
