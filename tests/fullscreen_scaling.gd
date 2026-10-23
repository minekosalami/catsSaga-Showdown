extends SceneTree
## Standalone native-window regression. Requires an isolated user-data directory.
var settings: Node
var session: Node
var output := OS.get_temp_dir().path_join("catsSaga-display-scaling")
var checks := 0
var failures := 0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or DisplayServer.get_name()=="headless":
		push_error("Run with a native display, isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	create_timer(120).timeout.connect(func():push_error("Fullscreen validation timed out");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func frame_coverage(label_text: String,fullscreen: bool) -> void:
	var native := DisplayServer.window_get_size()
	var stretch := root.get_stretch_transform()
	var covered := stretch*root.get_visible_rect()
	check(covered.position.length()<1 and covered.size.distance_to(Vector2(native))<1,label_text+": rendered content covers the entire native client area")
	check(is_equal_approx(stretch.x.length(),stretch.y.length()),label_text+": uniform scaling preserves artwork aspect ratio")
	check(root.size==native,label_text+": root render target follows the actual window")
	if fullscreen:
		var screen := root.current_screen
		check(settings.current_display_mode()!=0 and native==DisplayServer.screen_get_size(screen) and DisplayServer.window_get_position()==DisplayServer.screen_get_position(screen),label_text+": actual fullscreen geometry equals the native monitor")
	if current_scene is Control:
		check(current_scene.size.is_equal_approx(root.get_visible_rect().size),label_text+": anchored scene fills the logical viewport")
		var background := current_scene.get_node_or_null("Background") as Control
		if background!=null:check(background.size.is_equal_approx(current_scene.size),label_text+": background fills the scene")
	print("GEOMETRY ",label_text," ",JSON.stringify({"native":str(native),"screen":str(DisplayServer.screen_get_size()),"mode":settings.current_display_mode(),"backend_mode":DisplayServer.window_get_mode(),"logical":str(root.get_visible_rect().size),"stretch":str(stretch)}))
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var pixels := root.get_texture().get_image()
	check(pixels.get_size()==DisplayServer.window_get_size(),name+": actual rendered screenshot has native client dimensions")
	pixels.save_png(output.path_join(name+".png"))
func alt_enter(view: Viewport) -> void:
	var key := InputEventKey.new()
	key.keycode=KEY_ENTER;key.alt_pressed=true;key.pressed=true
	view.push_input(key)
	key=key.duplicate();key.pressed=false;view.push_input(key)
	await create_timer(.2).timeout
func run() -> void:
	settings=root.get_node("GameSettings")
	session=root.get_node("Session")
	await session.main_menu()
	await create_timer(.3).timeout
	if "--restart" in OS.get_cmdline_user_args():
		check(settings.values.display_mode==1,"confirmed fullscreen preference survives process restart")
		frame_coverage("restarted-fullscreen",true)
		await shot("restarted-fullscreen")
		settings.preview_display(0,settings.values.window_size)
		await create_timer(.2).timeout
		check(DisplayServer.window_get_size()==Vector2i(960,540) and not root.borderless,"restarted game restores the saved normal window dimensions and borders")
		settings.confirm_display()
	else:
		frame_coverage("initial-windowed",false)
		session.open_options()
		var options: AcceptDialog=session.options_dialog
		options.display_mode_picker.select(1)
		var apply: Button=options.find_children("*","Button",true,false).filter(func(b):return b.text=="Apply Display")[0]
		apply.pressed.emit()
		await create_timer(.3).timeout
		frame_coverage("apply-fullscreen",true)
		await shot("fullscreen-settings")
		options.keep.pressed.emit()
		check(settings.values.display_mode==1 and options.display_mode_picker.get_selected_id()==1,"Keep persists fullscreen and Settings reports the effective mode")
		options.hide()
		await shot("fullscreen-main-menu")
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(960,540)]:
			settings.preview_display(0,size)
			await create_timer(.15).timeout
			check(DisplayServer.window_get_size()==size and not root.borderless,"Windowed uses selected %s resolution with normal borders"%size)
			frame_coverage("windowed-cycle",false)
			settings.confirm_display()
			await alt_enter(root)
			frame_coverage("Alt+Enter-fullscreen",true)
			settings.confirm_display()
			await alt_enter(session.options_dialog)
			check(DisplayServer.window_get_size()==size and settings.current_display_mode()==0,"Alt+Enter in Settings restores previous window size")
			settings.confirm_display()
			session.options_dialog.hide()
		# An ordinary manual resize has a different aspect than the 16:9 base.
		root.position=Vector2i(40,40)
		root.size=Vector2i(1600,1000)
		await create_timer(.2).timeout
		frame_coverage("resized-16-10-window",false)
		await shot("expanded-window")
		settings.preview_display(0,Vector2i(960,540))
		await create_timer(.1).timeout
		settings.confirm_display()
		var previous: Dictionary=settings.display_state()
		settings.preview_display(1,settings.values.window_size)
		await create_timer(.15).timeout
		settings.trial_seconds=.05
		await create_timer(.15).timeout
		check(not settings.trial and settings.display_state()==previous,"timed-out fullscreen trial restores geometry, mode and border flags")
		settings.preview_display(1,settings.values.window_size)
		await create_timer(.2).timeout
		settings.confirm_display()
		if not "--geometry-only" in OS.get_cmdline_user_args():
			await session.new_game()
			await create_timer(.2).timeout
			frame_coverage("fullscreen-exploration",true)
			var player: Node2D=current_scene.player
			settings.set_value("zoom",1.0)
			await process_frame
			var normal: float=player.get_canvas_transform().affine_inverse().basis_xform(Vector2(root.get_visible_rect().size.x,0)).length()
			settings.set_value("zoom",.75)
			await process_frame
			var wide: float=player.get_canvas_transform().affine_inverse().basis_xform(Vector2(root.get_visible_rect().size.x,0)).length()
			check(absf(wide/normal-1.0/.75)<.01,"75% exploration zoom increases measured world visibility without changing root display scaling")
			await shot("fullscreen-exploration")
			var history: Array[String]=[]
			session.battle_transition.stage_changed.connect(func(stage):history.append(stage))
			await session.begin_battle(player.position)
			check(history.slice(history.find("freeze"))==["freeze","blackout","cat_flash","loading","travel","star_flash","cat_return","reveal","idle"],"protected entry retains its exact stage order in fullscreen")
			var host := current_scene
			frame_coverage("fullscreen-battle",true)
			check(host.arena.size==Vector2i(540,900),"battle simulation remains 540x900")
			var rect: Rect2=host.arena_container.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,Vector2(host.arena.size))
			rect=root.get_stretch_transform()*rect
			check(absf(rect.size.y-DisplayServer.window_get_size().y)<1 and absf(rect.size.x/rect.size.y-540.0/900)<.001,"portrait battle fills the full monitor height with its original aspect ratio")
			check(host.battle.music_player.playing and host.battle.player.can_process(),"battle music and controls start after the protected reveal")
			await create_timer(.3).timeout
			settings.toggle_fullscreen()
			await create_timer(.2).timeout
			check(paused and session.pause_menu.opened,"display toggle during battle opens Settings with gameplay paused")
			var clock: float=host.battle.elapsed_time
			var audio: float=host.battle.music_player.get_playback_position()
			await create_timer(.2).timeout
			check(is_equal_approx(host.battle.elapsed_time,clock) and absf(host.battle.music_player.get_playback_position()-audio)<.06,"battle clock and soundtrack stay paused while changing display")
			settings.confirm_display()
			session.options_dialog.hide()
			settings.toggle_fullscreen()
			await create_timer(.2).timeout
			settings.confirm_display()
			session.options_dialog.hide()
			await create_timer(.3).timeout
			var mixed_time: float=host.battle.music_player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
			check(not paused and host.battle.elapsed_time>clock and absf(host.battle.elapsed_time-mixed_time)<.12,"battle resumes synchronized after returning to fullscreen")
			frame_coverage("battle-after-mode-switch",true)
			await shot("fullscreen-battle")
			await session.main_menu()
	root.get_node("Music").play_theme("")
	print("FULLSCREEN SCALING: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
