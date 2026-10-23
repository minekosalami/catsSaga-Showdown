extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	create_timer(40).timeout.connect(func():push_error("Save restart timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func run() -> void:
	root.size=Vector2i(1280,720)
	var session: Node=root.get_node("Session")
	var first: Dictionary=session.saves.read_slot(1)
	check(not first.is_empty() and not session.saves.read_slot(2).is_empty() and not session.saves.read_slot(3).is_empty(),"all three manual slots survive process restart")
	await session.main_menu()
	current_scene.menu_container.get_node("ContinueButton").pressed.emit()
	while session.busy:await process_frame
	check(current_scene.name=="Overworld","real Continue button loads a valid slot")
	await session.main_menu()
	current_scene._start_game()
	current_scene._load_slot(2)
	while session.busy:await process_frame
	check(current_scene.name=="Overworld" and session.active_slot==2 and session.story_flags.slot_2,"another existing slot can be selected and loaded")
	await session.load_game(1)
	var statue: Node2D=current_scene.map.find_child("CatSaveStatue",true,false)
	current_scene.player.position=statue.position+Vector2(0,58)
	session.open_save_point(statue)
	session.story_flags["second_manual_save"]=true
	session.confirmation.confirmed.emit()
	await process_frame
	check(FileAccess.file_exists(session.saves.slot_path(1)+".bak"),"repeated manual save retains previous valid backup")
	var file := FileAccess.open(session.saves.slot_path(1),FileAccess.WRITE)
	file.store_string("deliberately corrupt isolated fixture");file.close()
	check(await session.load_game(1),"corrupt primary recovers validated backup")
	check(not session.story_flags.get("second_manual_save",false),"recovery uses exact older checkpoint")
	check(session.get_node_or_null("DebugNotification")!=null,"backup recovery is reported in-game")
	await session.main_menu()
	current_scene._start_game()
	current_scene._select_new_slot(1)
	session.confirmation.confirmed.emit()
	while session.busy:await process_frame
	check(current_scene.name=="Overworld" and session.fresh_run and session.active_slot==1,"confirmed replacement starts a fresh run in selected slot")
	check(FileAccess.get_file_as_string(session.saves.slot_path(1)).begins_with("deliberately"),"starting replacement retains existing disk data until deliberate save")
	session.story_flags["unsaved_fresh_run"]=true
	await session.retry_last_save()
	check(session.fresh_run and not session.story_flags.get("unsaved_fresh_run",false) and session.area_id=="entrance","death before first manual save returns to fresh entrance")
	# The new run's first manual save preserves even the unreadable replaced file.
	statue=current_scene.map.find_child("CatSaveStatue",true,false)
	current_scene.player.position=statue.position+Vector2(0,58)
	session.open_save_point(statue);session.confirmation.confirmed.emit()
	await process_frame
	check(FileAccess.file_exists(session.saves.slot_path(1)+".invalid.bak") and not session.saves.read_slot(1).is_empty(),"deliberate replacement preserves unreadable primary and writes a valid new slot")
	var before := FileAccess.get_file_as_string(session.saves.slot_path(1))
	session.story_flags["unsaved_after_statue"]=true
	session.open_pause()
	session.request_main_menu()
	check(is_instance_valid(session.confirmation),"leaving unsaved gameplay requires confirmation")
	session.confirmation.canceled.emit()
	await process_frame
	check(paused and current_scene.name=="Overworld","cancelling return preserves paused game")
	session.request_main_menu();session.confirmation.confirmed.emit()
	while session.busy:await process_frame
	check(current_scene.name=="Mainmenu" and not paused and FileAccess.get_file_as_string(session.saves.slot_path(1))==before,"confirmed return resumes menu music without saving")
	root.get_node("Music").play_theme("")
	print("SAVE RESTART: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
