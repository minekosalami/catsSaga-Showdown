extends SceneTree
var failures := 0
var checks := 0
var session: Node
var settings: Node
var output := ""
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	create_timer(120).timeout.connect(func():push_error("Menu test timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func key(code: Key,pressed: bool=true,alt: bool=false) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=pressed
	event.alt_pressed=alt
	Input.parse_input_event(event)
func joy(button: JoyButton,pressed: bool=true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=pressed
	Input.parse_input_event(event)
func shot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("Session")
	settings=root.get_node("GameSettings")
	check(session.saves.most_recent_slot()==0,"fresh isolated profile has no Continue save")
	await session.main_menu()
	await create_timer(.4).timeout
	var menu := current_scene
	var texts: Array[String]=[]
	for child in menu.menu_container.get_children():
		if child is Button:texts.append(child.text)
	check(texts==["Continue","New Game","Settings","Records","Credits","Quit"],"exact requested main menu order")
	check(menu.menu_container.get_node("ContinueButton").disabled,"Continue disabled without valid slot")
	check(root.get_node("Music").player.playing and root.get_node("Music").player.bus==&"Music","one looping menu music player routed to Music")
	await shot("01-main-menu")
	var focused := root.gui_get_focus_owner()
	key(KEY_DOWN);key(KEY_DOWN,false)
	await process_frame
	check(root.gui_get_focus_owner()!=focused,"arrow navigation moves visible focus")
	joy(JOY_BUTTON_DPAD_UP);joy(JOY_BUTTON_DPAD_UP,false)
	await process_frame
	check(root.gui_get_focus_owner()==focused,"controller D-pad navigates menu")
	joy(JOY_BUTTON_A);joy(JOY_BUTTON_A,false);Input.flush_buffered_events()
	await process_frame
	check(menu.page_kind=="slots","controller A activates the focused New Game button")
	menu.go_back()
	await process_frame
	var credits_button: Button=menu.menu_container.get_node("CreditsButton")
	var mouse := InputEventMouseButton.new()
	mouse.position=credits_button.get_global_rect().get_center()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	Input.parse_input_event(mouse)
	mouse=mouse.duplicate();mouse.pressed=false;Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	check(menu.page_kind=="credits" and menu.page.get_child(1).text.contains("LLiosette — Creator"),"credits show actual creator and source notices")
	await create_timer(.3).timeout
	await shot("02-credits")
	key(KEY_ESCAPE);key(KEY_ESCAPE,false)
	await process_frame
	check(menu.page_kind.is_empty(),"Escape returns from credits")
	menu._start_game()
	check(not FileAccess.file_exists(session.saves.slot_path(1)),"opening New Game does not create or overwrite progress")
	await create_timer(.3).timeout
	await shot("03-save-slots")
	menu.go_back()
	menu.menu_container.get_node("SettingsButton").pressed.emit()
	await process_frame
	var options: AcceptDialog=session.options_dialog
	check(options.visible and options.tabs.get_tab_count()==4,"Settings has Display, Audio, Controls and Gameplay pages")
	await shot("04-settings-display")
	options.controls.music.value=35
	options.controls.sfx.value=60
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),.35),"music slider changes real bus gain immediately")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")),.6),"SFX has independent gain")
	options.controls.master.value=0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"zero master volume mutes output")
	options.controls.master.value=100
	check(not settings.bind_key("move_left",KEY_D).is_empty(),"binding conflict rejected")
	check(not settings.bind_key("attack",KEY_MINUS).is_empty(),"developer/menu key reserved")
	check(settings.bind_key("attack",KEY_Q).is_empty(),"attack can be rebound")
	check(settings.binding_label("attack")=="Q","binding label reflects actual action")
	options.tabs.current_tab=2
	await process_frame
	await shot("05-settings-controls")
	options.hide()
	settings.bindings.clear();settings.install_actions();settings.save_preferences()
	await session.new_game(1)
	await create_timer(.1).timeout
	check(not FileAccess.file_exists(session.saves.slot_path(1)),"New Game starts without automatically writing progress")
	var world := current_scene
	var statues: Array=[]
	for npc in get_nodes_in_group("interactables"):
		if npc.has_meta("save_statue"):statues.append(npc)
	check(statues.size()==1,"Forest Entrance has one reusable cat statue")
	world.player.position=statues[0].position+Vector2(0,62)
	await create_timer(.1).timeout
	check(world.nearest_npc==statues[0],"statue selected by existing interaction radius")
	key(KEY_Z);key(KEY_Z,false)
	await process_frame
	check(session.save_point_active and paused and is_instance_valid(session.confirmation),"interaction opens deliberate Save/Cancel and freezes world")
	session.confirmation.canceled.emit()
	await process_frame
	check(not paused and not FileAccess.file_exists(session.saves.slot_path(1)),"Cancel leaves disk unchanged and resumes")
	session.open_save_point(statues[0])
	session.confirmation.confirmed.emit()
	await process_frame
	check(not paused and not session.saves.read_slot(1).is_empty(),"explicit statue confirmation writes a validated slot")
	var first: Dictionary=session.saves.read_slot(1)
	var first_bytes := FileAccess.get_file_as_string(session.saves.slot_path(1))
	check(not session.save_current(),"saving away from statue rejected")
	settings.set_value("zoom",.75)
	await process_frame
	check(world.player.get_node("Camera2D").zoom==Vector2(.75,.75),"75% exploration zoom widens visibility without touching player coordinates")
	var camera: Camera2D=world.player.get_node("Camera2D")
	camera.followed=world.player.global_position
	camera.global_position=world.player.global_position
	camera.force_update_scroll()
	await create_timer(.25).timeout
	await shot("06-statue-and-wide-view")
	await session.travel("deep_forest","FromEntrance")
	check(FileAccess.get_file_as_string(session.saves.slot_path(1))==first_bytes,"region travel does not autosave")
	for area in ["deep_forest","bart_area","flooded_forest"]:
		if session.area_id!=area:await session.travel(area,"Start")
		world=current_scene
		for statue in get_nodes_in_group("interactables"):
			if not statue.has_meta("save_statue"):continue
			check(world.map.is_walkable_position(statue.position),area+" statue stands on dry walkable ground")
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape=world.player.get_node("CollisionShape2D").shape
			query.transform=Transform2D(0,statue.position+Vector2(0,58))
			query.collision_mask=1
			await physics_frame
			check(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),area+" statue has unobstructed approach")
		await shot("07-statue-"+area)
	# Independent slots, using the same real statue interaction.
	for slot in [2,3]:
		await session.new_game(slot)
		world=current_scene
		var statue: Node2D=world.map.find_child("CatSaveStatue",true,false)
		world.player.position=statue.position+Vector2(0,58)
		session.open_save_point(statue)
		session.story_flags["slot_%d"%slot]=true
		session.confirmation.confirmed.emit()
		await process_frame
		check(session.saves.read_slot(slot).story_flags.get("slot_%d"%slot,false),"independent manual Slot %d"%slot)
	check(FileAccess.get_file_as_string(session.saves.slot_path(1))==first_bytes,"other slots do not overwrite Slot 1")
	check(session.saves.most_recent_slot()==3,"Continue chooses most recently used valid slot")
	await session.load_game(1)
	check(session.active_slot==1 and session.saves.most_recent_slot()==1,"loading updates last-used slot")
	# Unsaved progression must be rolled back by a real defeat + retry.
	session.story_flags["unsaved_victory"]=true
	session.encounter_active=true
	session.encounter_id="bart"
	session.return_position=current_scene.player.position
	await session.transition_to("res://scenes/combat_host.tscn")
	var host := current_scene
	var battle: Node=host.battle
	check(host.arena.size==Vector2i(540,900),"battle retains exact internal resolution despite exploration zoom")
	battle.player.invincible=true
	await create_timer(.2).timeout
	key(KEY_Z)
	await create_timer(.22).timeout
	key(KEY_Z,false)
	check(get_nodes_in_group("player_bullets").size()>0 or battle.player.shoot_timer>0,"default shooting still works")
	key(KEY_X);key(KEY_X,false)
	await process_frame
	check(battle.player.saturate_used,"SATURATE action remains available in attacking fight")
	key(KEY_ESCAPE);key(KEY_ESCAPE,false)
	await process_frame
	check(paused and session.pause_menu.opened,"Escape pauses combat")
	var clock: float=battle.elapsed_time
	var music_position: float=battle.music_player.get_playback_position()
	var player_position: Vector2=battle.player.position
	await create_timer(.3).timeout
	check(is_equal_approx(battle.elapsed_time,clock) and battle.player.position==player_position,"combat clock and movement freeze during pause")
	check(absf(battle.music_player.get_playback_position()-music_position)<.06,"actual soundtrack playback freezes during pause")
	await shot("08-pause")
	key(KEY_ESCAPE);key(KEY_ESCAPE,false)
	await create_timer(.2).timeout
	check(not paused and battle.elapsed_time>clock and battle.music_player.get_playback_position()>music_position,"music and combat resume together")
	battle.player.invincible=false
	for hit in range(3):battle.player.invulnerability_timer=0; battle.player.take_damage(1)
	await create_timer(.8).timeout
	while session.busy:await process_frame
	check(current_scene.name=="Overworld" and session.active_slot==1 and session.story_flags.get("unsaved_victory",false),"death returns to checkpoint while preserving earned progression")
	check(session.saves.read_slot(1).story_flags.get("unsaved_victory",false),"death persists earned flags separately from manual checkpoint")
	check(FileAccess.get_file_as_string(session.saves.slot_path(1))==first_bytes,"death preserves manual checkpoint file")
	await session.main_menu()
	menu=current_scene
	menu._start_game()
	menu._select_new_slot(1)
	check(is_instance_valid(session.confirmation),"occupied New Game slot requires overwrite confirmation")
	session.confirmation.canceled.emit()
	await process_frame
	check(FileAccess.get_file_as_string(session.saves.slot_path(1))==first_bytes,"cancelled overwrite preserves previous save")
	menu.go_back()
	# Real legacy backup + migration in this isolated profile, never user's actual directory.
	var legacy := first.duplicate(true)
	legacy.erase("playtime")
	var file := FileAccess.open("user://save.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	# Slots occupied: migration must preserve legacy source rather than overwrite them.
	var message: String=session.saves.migrate_legacy()
	check(message.contains("occupied") and FileAccess.file_exists("user://save.json"),"full-slot legacy migration preserves original and reports issue")
	var before := FileAccess.get_file_as_string("user://save.json")
	DirAccess.remove_absolute(session.saves.slot_path(3))
	DirAccess.remove_absolute(session.saves.progress_path(3))
	DirAccess.remove_absolute(session.saves.progress_path(3)+".bak")
	message=session.saves.migrate_legacy()
	check(not session.saves.read_slot(3).is_empty() and FileAccess.get_file_as_string("user://save.json")==before and FileAccess.file_exists("user://save.json.pre-slots.bak"),"legacy progress migrates with original and immutable backup intact")
	check(session.saves.read_slot(3).playtime==0.0,"legacy saves gain safe missing playtime default")
	check(not await session.load_game(9),"invalid load reports failure without starting New Game")
	check(current_scene.name=="Mainmenu","failed load leaves current scene intact")
	var prefs := ConfigFile.new()
	check(prefs.load("user://settings.cfg")==OK and prefs.get_value("settings","zoom")==.75 and prefs.get_value("settings","music")==.35,"settings persist independently of slots")
	root.get_node("Music").play_theme("")
	print("MENU OVERHAUL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
