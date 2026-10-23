extends SceneTree
var output := OS.get_temp_dir().path_join("catsSaga-menu-statues")
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var session: Node=root.get_node("Session")
	await session.new_game()
	DirAccess.make_dir_recursive_absolute(output)
	root.get_node("GameSettings").set_value("zoom",1.0)
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		if area!="entrance":await session.travel(area,"Start")
		var world := current_scene
		var index := 0
		for statue in get_nodes_in_group("interactables"):
			if not statue.has_meta("save_statue"):continue
			index+=1
			world.player.position=statue.position+Vector2(0,58)
			var camera: Camera2D=world.player.get_node("Camera2D")
			camera.followed=world.player.global_position
			camera.global_position=world.player.global_position
			camera.force_update_scroll()
			await create_timer(.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("statue-%s-%d.png"%[area,index]))
			print("STATUE ",area," ",statue.position," player screen ",world.player.get_global_transform_with_canvas().origin)
	await session.main_menu()
	root.get_node("Music").play_theme("")
	quit()
