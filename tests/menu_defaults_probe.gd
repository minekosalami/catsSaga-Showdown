extends SceneTree
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1.")
		quit(1)
		return
	run.call_deferred()
func run() -> void:
	var session: Node=root.get_node("Session")
	var settings: Node=root.get_node("GameSettings")
	await session.main_menu()
	session.open_options()
	var options: AcceptDialog=session.options_dialog
	options.controls.master.value=20
	settings.set_value("zoom",.75)
	settings.set_value("shake",false)
	settings.set_value("flashing",true)
	settings.bind_key("attack",KEY_Q)
	root.get_node("VisualSettings").set_reduced(true)
	root.get_node("VisualSettings").set_motion(0)
	var restore: Button=options.find_children("*","Button",true,false).filter(func(b):return b.text=="Restore All Defaults")[0]
	restore.pressed.emit()
	session.confirmation.canceled.emit()
	await process_frame
	var ok: bool=settings.values.master==.2 and settings.values.zoom==.75
	restore.pressed.emit()
	session.confirmation.confirmed.emit()
	await process_frame
	ok=ok and settings.values.master==1.0 and settings.values.music==1.0 and settings.values.sfx==1.0 and settings.values.zoom==1.0 and settings.values.shake and not settings.values.flashing and settings.bindings.is_empty()
	ok=ok and not root.get_node("VisualSettings").reduced and root.get_node("VisualSettings").motion==.8 and settings.trial
	options.keep.pressed.emit()
	ok=ok and not settings.trial and not session.saves.slot_exists(1)
	print("DEFAULTS UI ","PASS" if ok else "FAIL",": cancel preserves preferences, confirmed reset restores defaults with display confirmation and no gameplay save")
	options.hide()
	root.get_node("Music").play_theme("")
	quit(0 if ok else 1)
