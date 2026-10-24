extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	create_timer(45).timeout.connect(func():quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures+=1;push_error("FAIL: "+message)
func enter(name: String) -> void:
	var world: Node = current_scene
	world.player.position = world.map.get_node("Portals/"+name).position
	world.player.velocity = Vector2.ZERO
	for i in range(4):await physics_frame
	while root.get_node("Session").busy:await process_frame
	await process_frame
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://journey-transitions.json"
	await session.new_game()
	session.story_flags["smoki_interacted"]=true
	session.story_flags["blankkitten_defeated"]=true
	var music: Node = root.get_node("Music")
	var stream: AudioStream = music.player.stream
	var start: float = music.player.get_playback_position()
	await enter("ToRight")
	check(session.area_id=="deep_forest","real entrance overlap reaches Deep Forest")
	await enter("ToRight")
	check(session.area_id=="bart_area","real Deep Forest overlap reaches Bart's area")
	await enter("ToRight")
	check(session.area_id=="bart_area" and not session.busy,"physical locked gate does not transition")
	current_scene.player.position -= Vector2(250,0)
	await physics_frame
	await physics_frame
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await enter("ToRight")
	check(session.area_id=="flooded_forest","physical key gate opens after existing victory flag")
	check(music.player.stream==stream and music.player.get_playback_position()>start,"forest soundtrack remains continuous through real portals")
	for area in ["bart_area","deep_forest","entrance"]:
		await enter("ToLeft")
		check(session.area_id==area,"physical return seam reaches "+area)
		check(current_scene.player.position.distance_to(current_scene.map.get_node("Entries/"+session.entry_marker).position)<2,"destination spawn stays out of return trigger")
	var world: Node = current_scene
	var map_ui: Node = world.map_ui
	map_ui.open_map()
	check(map_ui.opened and not world.map.visible,"map modal opens over actual new terrain")
	check(map_ui.full_map.center_world==Vector2(488,96) and map_ui.full_map.zoom<1.3,"full map fits the horizontal journey")
	var center: Vector2 = map_ui.full_map.center_world
	var press := InputEventKey.new()
	press.keycode = KEY_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await create_timer(.12).timeout
	press = InputEventKey.new()
	press.keycode = KEY_RIGHT
	press.pressed = false
	Input.parse_input_event(press)
	check(map_ui.full_map.center_world.x>center.x,"existing map pan input still works")
	var zoom: float = map_ui.target_zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	map_ui.handle_input(wheel)
	check(map_ui.target_zoom>zoom,"existing map scroll zoom still works")
	map_ui.close_modals()
	await process_frame
	check(not map_ui.modal_open() and world.map.visible and world.player.visible,"closing the map restores exploration rendering")
	check(session.exploration.region_discovered("entrance"),"new terrain discovery is recorded")
	print("JOURNEY TRANSITIONS: ",checks," checks, ",failures," failures")
	await session.main_menu()
	music.play_theme("")
	quit(1 if failures else 0)
