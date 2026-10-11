extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
var output := "/workspace/.catsSaga-validation/cave-render"
var checks := 0
var failures := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func capture(name: String) -> void:
	await create_timer(.1).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(),name+" renders")
	image.save_png(output.path_join(name+".png"))
func position(world: Node, point: Vector2) -> void:
	world.player.position = point
	var camera: Camera2D = world.player.get_node("Camera2D")
	camera.reset_smoothing()
	camera.force_update_scroll()
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cave-render.json"
	await session.travel("flooded_forest","FromDeep")
	var world: Node = current_scene
	position(world,world.map.get_node("Characters/CaveHole").position+Vector2(0,70))
	await capture("forest-hole")
	await session.travel("underground_cave","FromFlooded",true)
	world = current_scene
	var times: Array[float] = []
	for index in Plan.ROOMS.size():
		position(world,Plan.center(index))
		world.update_map_exploration()
		await capture("chamber-"+str(index))
		check(world.map.is_walkable_position(world.player.position),"room "+str(index)+" floor visible and walkable")
	position(world,Vector2(Plan.ROUTES[0][2])*32)
	await capture("winding-tunnel")
	position(world,Plan.center(7)+Vector2(400,0))
	await capture("rock-boundary")
	world.map_ui.open_map()
	await capture("underground-map")
	check(world.map_ui.opened and world.map_ui.full_map.shader.get_shader_parameter("atlas_size") == Vector2(1280,1024),"underground map uses the separate atlas")
	world.map_ui.close_modals()
	position(world,Plan.center(4))
	for i in 90:
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		if i > 20: times.append((Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	print("CAVE SOFTWARE PROFILE median_ms=",times[times.size()/2]," p95_ms=",times[int(times.size()*.95)]," nodes=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await session.travel("flooded_forest","FromCave",true)
	world = current_scene
	world.map_ui.open_map()
	await capture("forest-map-restored")
	check(world.map_ui.full_map.shader.get_shader_parameter("atlas_size") == Vector2(520,372),"return restores forest map dimensions")
	world.map_ui.close_modals()
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(.2).timeout
	print("CAVE RENDER: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
