extends SceneTree
## Save-marker discovery uses ordinary persisted fog; no marker/story flags added.
const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node

func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		push_error("Use CATSSAGA_TEST_PROFILE=1 and a fresh isolated XDG_DATA_HOME.")
		quit(1)
		return
	create_timer(60).timeout.connect(func():push_error("Save-marker validation timed out");quit(1))
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)

func markers() -> Array:
	return current_scene.map_ui.visible_boss_markers().filter(func(marker):return str(marker.id).begins_with("save_"))

func marker_ids() -> Array:
	var ids:=markers().map(func(marker):return marker.id)
	ids.sort()
	return ids

func run() -> void:
	session=root.get_node("Session")
	await session.new_game(3)
	await process_frame
	var script: Script=load("res://scripts/world/save_statue.gd")
	var locations: Dictionary=script.get_script_constant_map().LOCATIONS
	session.reveal_all_locations=false
	session.exploration.reset()
	check(markers().is_empty(),"undiscovered save points are hidden with empty fog")
	session.exploration.reveal("entrance",current_scene.player.position)
	check(markers().is_empty(),"exploring the distant entrance does not reveal a save point")
	session.map_reveal_cheat=true
	check(markers().is_empty(),"terrain-reveal cheat does not silently discover save points")
	session.map_reveal_cheat=false
	var total:=0
	for area: String in locations:
		for index in locations[area].size():
			total+=1
			var point: Vector2=locations[area][index]
			session.exploration.reset()
			session.exploration.reveal(area,point)
			var found:=markers()
			check(found.size()==1,"only the nearby star is revealed: "+area+"/"+str(index))
			if found.is_empty():continue
			var marker: Dictionary=found[0]
			check(marker.id=="save_"+area+"_"+str(index) and marker.discovered and marker.label=="Save","discovered star has the existing map label/state")
			var expected: Vector2=Vector2(Layout.REGIONS[area].offset)+point/16.0
			check(marker.area==area and marker.local_position.is_equal_approx(point) and marker.point.is_equal_approx(expected),"save marker matches the actual star's regional and world coordinates")
			current_scene.map_ui._refresh()
			check(current_scene.map_ui.minimap.boss_markers==current_scene.map_ui.full_map.boss_markers,"minimap and WORLD_MAP share the same discovered star markers")
	# Discover three separated stars, then use the actual manual-save confirmation.
	session.exploration.reset()
	for area in ["entrance","deep_forest","flooded_forest"]:session.exploration.reveal(area,locations[area][0])
	var world:=current_scene
	var star: Node2D=world.map.find_child("CatSaveStatue",true,false)
	var star_position:=star.position
	world.player.position=star.position+Vector2(0,58)
	await process_frame
	await process_frame
	var expected_ids:=marker_ids()
	check(expected_ids.size()==3,"three visited stars are visible before saving")
	session.open_save_point(star)
	check(session.save_point_active and is_instance_valid(session.confirmation),"real star opens the deliberate save confirmation")
	session.confirmation.confirmed.emit()
	await process_frame
	var saved: Dictionary=session.saves.read_slot(3)
	var path: String=session.saves.slot_path(3)
	var saved_bytes:=FileAccess.get_file_as_string(path)
	check(not saved.is_empty(),"manual save writes the current fog to the selected slot")
	session.exploration.reset()
	check(markers().is_empty(),"reset fog hides the markers without any separate discovery flags")
	check(await session.load_game(3),"manual slot reload succeeds")
	check(marker_ids()==expected_ids,"save-point discovery survives actual disk save/load")
	check(FileAccess.get_file_as_string(path)==saved_bytes,"loading does not rewrite the manual save")
	session.reveal_all_locations=true
	check(markers().size()==total and markers().filter(func(marker):return marker.discovered).size()==3,"location debug override exposes remaining markers without discovering them")
	session.reveal_all_locations=false
	check(marker_ids()==expected_ids,"disabling the override restores normal fog restrictions")
	# A legacy v1 save has no star-specific flags and only its original fog region.
	var legacy: Dictionary={"version":1,"area":"entrance","position":[star_position.x,star_position.y+58],"evil_bart_defeated":false,"story_flags":{},"exploration":{"entrance":saved.exploration.entrance}}
	check(not session.saves.validate(legacy).is_empty(),"legacy partial fog is accepted without new marker flags")
	if FileAccess.file_exists("user://save.json"):
		check(false,"legacy fixture requires a fresh isolated profile")
	else:
		var legacy_bytes:=JSON.stringify(legacy)
		var file:=FileAccess.open("user://save.json",FileAccess.WRITE)
		file.store_string(legacy_bytes);file.close()
		var message: String=session.saves.migrate_legacy()
		check(not message.is_empty() and not session.saves.read_slot(1).is_empty(),"legacy migration writes an available slot successfully")
		check(FileAccess.get_file_as_string("user://save.json")==legacy_bytes and FileAccess.get_file_as_string("user://save.json.pre-slots.bak")==legacy_bytes,"legacy migration preserves original data and immutable backup")
		check(await session.load_game(1),"migrated legacy slot loads successfully")
		check(marker_ids()==["save_entrance_0"],"legacy fog reveals its visited star and keeps other regions' stars hidden")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("SAVE MARKERS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
