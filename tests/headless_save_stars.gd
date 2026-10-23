extends SceneTree
## Exercises the real save-point interaction and disk failure path in a fresh profile.
var checks := 0
var failures := 0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use CATSSAGA_TEST_PROFILE=1 and a fresh isolated XDG_DATA_HOME.")
		quit(1)
		return
	create_timer(60).timeout.connect(func():push_error("Save-star validation timed out");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func interact() -> void:
	var key := InputEventKey.new()
	key.keycode=KEY_Z;key.pressed=true
	Input.parse_input_event(key)
	key=key.duplicate();key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
func run() -> void:
	var session := root.get_node("Session")
	await session.new_game(2)
	await create_timer(.15).timeout
	var world := current_scene
	var star: Node2D=world.map.find_child("CatSaveStatue",true,false)
	check(star!=null and star.has_node("Star") and not star.has_node("Cat") and not star.has_node("Pedestal"),"save point uses one star visual without a cat or pedestal")
	check(FileAccess.get_sha256("res://assets/save_star_human/star.png")=="7cef301325d50f5b30dde827bb11da147753ac93ae2f4b310a5ba1d56217a1dc","human-created icon remains byte-identical to its licensed source")
	var low := INF
	var high := -INF
	for i in 12:
		await create_timer(.18).timeout
		low=minf(low,star.get_node("Star").position.y)
		high=maxf(high,star.get_node("Star").position.y)
	check(high-low>7 and high-low<=8.01,"idle star has a gentle eight-pixel peak-to-peak bob")
	world.player.position=star.position+Vector2(0,58)
	await create_timer(.15).timeout
	check(world.nearest_npc==star,"save star is selected by the existing overworld interaction system")
	interact()
	await process_frame
	check(paused and session.save_point_active and is_instance_valid(session.confirmation),"Z opens the existing deliberate Save / Cancel confirmation")
	var paused_height: float=star.get_node("Star").position.y
	await create_timer(.25).timeout
	check(star.get_node("Star").position.y==paused_height,"star animation pauses with the world")
	session.confirmation.canceled.emit()
	await process_frame
	check(not paused and not FileAccess.file_exists(session.saves.slot_path(2)),"Cancel resumes exploration without saving")
	interact()
	await process_frame
	session.confirmation.confirmed.emit()
	await process_frame
	var saved_path: String=session.saves.slot_path(2)
	var saved_bytes := FileAccess.get_file_as_string(saved_path)
	var checkpoint: Dictionary=session.manual_checkpoint.duplicate(true)
	check(not session.saves.read_slot(2).is_empty() and session.saves.read_slot(1).is_empty(),"Save writes the active second slot only")
	check(session.get_node("DebugNotification").text=="Saved to Slot 2.","successful disk write produces the existing save confirmation")
	session.saves.save_path="user://missing-save-star-directory/save.json"
	session.story_flags["save_star_failure_probe"]=true
	interact()
	await process_frame
	session.confirmation.confirmed.emit()
	await process_frame
	check(session.get_node("DebugNotification").text=="Cannot open the save directory for writing.","failed disk write reports failure instead of a successful save")
	check(FileAccess.get_file_as_string(saved_path)==saved_bytes and session.manual_checkpoint==checkpoint,"failed save preserves the previous file and manual checkpoint")
	session.saves.save_path=saved_path
	session.encounter_active=true
	session.open_save_point(star)
	check(not session.save_point_active and not is_instance_valid(session.confirmation) and not paused,"saving is unavailable during an active boss encounter")
	session.encounter_active=false
	await session.main_menu()
	var menu := current_scene
	check(not menu.menu_container.get_node("ContinueButton").disabled,"Continue is enabled after the manual star save")
	menu.menu_container.get_node("ContinueButton").pressed.emit()
	await create_timer(.6).timeout
	check(current_scene.name=="Overworld" and session.active_slot==2 and not session.story_flags.get("save_star_failure_probe",false),"actual Continue restores the latest manual slot and excludes unsaved changes")
	check(FileAccess.get_file_as_string(saved_path)==saved_bytes,"Continue does not rewrite progress")
	root.get_node("Music").play_theme("")
	print("SAVE STARS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
