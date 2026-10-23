extends SceneTree
var checks := 0
var failures := 0
var output := ""
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	create_timer(65).timeout.connect(func():push_error("Display test timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func shot(name: String) -> void:
	if output.is_empty():return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	var settings: Node=root.get_node("GameSettings")
	var session: Node=root.get_node("Session")
	await session.main_menu()
	print("DISPLAY backend ",DisplayServer.get_name()," screen ",DisplayServer.screen_get_size())
	var before: Dictionary=settings.display_state()
	settings.preview_display(0,Vector2i(960,540))
	await create_timer(.25).timeout
	check(DisplayServer.window_get_size()==Vector2i(960,540) and settings.trial,"real window resolution changes with confirmation pending")
	await shot("10-windowed-960")
	settings.trial_seconds=.1
	await create_timer(.2).timeout
	check(not settings.trial and DisplayServer.window_get_size()==before.size,"unconfirmed display trial automatically rolls back")
	settings.preview_display(1,Vector2i(1280,720))
	await create_timer(.3).timeout
	check(settings.current_display_mode()==1 and DisplayServer.window_get_size()==DisplayServer.screen_get_size(),"borderless fullscreen actually covers the monitor")
	session.open_options()
	await process_frame
	await shot("11-fullscreen-confirmation")
	settings.confirm_display()
	check(settings.values.display_mode==1 and not settings.trial,"confirmed fullscreen preference persists")
	# Route through the modal's own input viewport as real focused-window input.
	var key := InputEventKey.new()
	key.keycode=KEY_ENTER;key.pressed=true;key.alt_pressed=true
	session.options_dialog.push_input(key)
	await create_timer(.3).timeout
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and settings.trial,"Alt+Enter in focused Settings toggles exactly once through rollback flow")
	settings.confirm_display()
	session.options_dialog.hide()
	if settings.exclusive_supported():
		settings.preview_display(2,Vector2i(1280,720))
		await create_timer(.3).timeout
		check(settings.current_display_mode() in [1,2] and DisplayServer.window_get_size()==DisplayServer.screen_get_size(),"exclusive request fills the monitor, with an honest borderless fallback if unsupported")
		settings.revert_display()
	settings.preview_display(0,Vector2i(960,540))
	settings.confirm_display()
	session.open_options()
	await process_frame
	await shot("12-small-settings")
	var options: Window=session.options_dialog
	check(options.size.x<=root.get_visible_rect().size.x and options.size.y<=root.get_visible_rect().size.y,"settings window fits logical viewport at smaller resolution")
	# Defaults confirmation must be a child of the currently exclusive modal.
	var restore: Button=options.find_children("*","Button",true,false).filter(func(b):return b.text=="Restore All Defaults")[0]
	restore.pressed.emit()
	await process_frame
	check(is_instance_valid(session.confirmation) and session.confirmation.visible and session.confirmation.get_parent()==options,"Restore Defaults confirmation is visible above Settings")
	await shot("13-defaults-confirmation")
	session.confirmation.canceled.emit()
	await process_frame
	options.hide()
	settings.set_value("zoom",.8)
	settings.set_value("master",.8)
	settings.bind_key("attack",KEY_Q)
	settings.set_value("shake",false)
	root.get_node("VisualSettings").set_reduced(true)
	root.get_node("VisualSettings").set_motion(.4)
	check(FileAccess.file_exists("user://settings.cfg"),"native display/audio/input/comfort settings written")
	root.get_node("Music").play_theme("")
	print("DISPLAY PROBE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
