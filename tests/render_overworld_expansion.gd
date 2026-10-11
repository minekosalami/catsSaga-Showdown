extends SceneTree

var directory := "/tmp/overworld-expansion-review"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory.path_join(label+".png"))
	if error != OK: push_error("Screenshot failed: "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	for filename in ["forest_entrance","deep_forest","bart_area","flooded_forest"]:
		var started := Time.get_ticks_usec()
		var map: Node2D = load("res://scenes/world/"+filename+".tscn").instantiate()
		root.add_child(map)
		var camera := Camera2D.new()
		root.add_child(camera)
		camera.position = map.map_size/2
		camera.zoom = Vector2.ONE*minf(1280.0/map.map_size.x,720.0/map.map_size.y)
		camera.make_current()
		await create_timer(0.12).timeout
		print(filename," instantiate+first frames ms=",(Time.get_ticks_usec()-started)/1000.0)
		await capture(filename+"-overview")
		camera.zoom = Vector2.ONE
		camera.position = map.get_node("Discoveries/SouthernGrove").position
		await create_timer(0.10).timeout
		await capture(filename+"-grove")
		map.free()
		camera.free()
	quit()
