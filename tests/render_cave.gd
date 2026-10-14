extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
var output := "user://cave-redesign-render"
var checks := 0
var failures := 0
var session: Node
var world: Node
func _initialize():
	create_timer(240).timeout.connect(func(): quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func capture(title: String):
	var image := await frame()
	check(not image.is_empty(),title+" renders")
	image.save_png(output.path_join(title+".png"))
func position(point: Vector2, zoom := 1.0):
	world.player.position = point
	var camera: Camera2D = world.player.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE*zoom
	camera.force_update_scroll()
	await process_frame
	await process_frame
func pixel(image: Image, point: Vector2) -> Vector2i:
	var screen: Vector2 = root.canvas_transform*world.map.global_transform*point
	return Vector2i(screen*Vector2(image.get_size())/root.get_visible_rect().size)
func probe(point: Vector2) -> Polygon2D:
	var node := Polygon2D.new()
	node.polygon = PackedVector2Array([Vector2(-12,-12),Vector2(12,-12),Vector2(12,12),Vector2(-12,12)])
	node.color = Color(.9,.02,.8)
	node.z_index = 100
	node.position = point
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR = vec4(.9,.02,.8,1.0); }"
	material.shader = shader
	node.material = material
	world.map.add_child(node)
	return node
func visible_sample(image: Image, point: Vector2) -> Color:
	var p := pixel(image,point)
	if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(p): return Color.BLACK
	return image.get_pixelv(p)
func gray_sample(image: Image, point: Vector2) -> bool:
	var p := Vector2i(point*Vector2(image.get_size())/root.get_visible_rect().size)
	var color := image.get_pixelv(p)
	return absf(color.r-color.g) < .01 and absf(color.r-color.b) < .01 and color.r > .1
func run():
	if DisplayServer.get_name() == "headless":
		push_error("Run render_cave with a graphical display; headless cannot test shaders.")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-cave-render.json"
	await session.new_game()
	await session.travel("underground_cave","FromFlooded")
	world = current_scene
	for id in [1,2,3,4,5,6,7,8,10,11,12,13,14,15,16]:
		await position(Plan.center(id-1)+Vector2(0,80))
		if id == 7: await create_timer(1.05).timeout
		await capture("area-"+str(id))
	await position(Plan.center(3))
	await capture("hub")
	await position(world.map.get_node("Characters/Merchant").position+Vector2(0,96))
	world.map.services.open_market()
	await capture("shop-placeholder")
	world.map.services.close_market()

	session.developer_menu.show_menu()
	await capture("developer")
	session.developer_menu.close_menu()
	# Diagnostic world probes test the actual rendered mask, including unusual zooms.
	var probes: Array[Polygon2D] = []
	for room in Plan.ROOMS: probes.append(probe(Plan.center(room.id-1)+Vector2(0,48)))
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await process_frame
		for active in [1,4,8]:
			await position(Plan.center(active-1)+Vector2(0,80),.2)
			var image := await frame()
			var covered := 0
			for id in range(1,17):
				var p := pixel(image,probes[id-1].position)
				if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(p): continue
				var logical := Vector2(p)*root.get_visible_rect().size/Vector2(image.get_size())
				if logical.y < 100 or logical.y > root.get_visible_rect().size.y-80 or (logical.x < 190 and logical.y < 185): continue
				var color := image.get_pixelv(p)
				if id == active: check(color.r > .5 and color.b > .5,"active room remains visible at "+str(size)+" / zoom .2")
				else:
					covered += 1
					check(color.r < .4 and color.b < .25,"Area %d masks Area %d at %s / zoom .2"%[active,id,str(size)])
			check(covered > 0,"wide view actually tests neighboring interiors")
	for node in probes: node.queue_free()
	root.size = Vector2i(1280,720)
	for route in Plan.ROUTES:
		var destination: Vector2 = route.points[-1]*32+Vector2(16,16)
		var nearest_interior := INF
		for cell in world.map.get_node("CaveFloor").get_used_cells():
			if world.map.cell_room(cell) != Vector2i(route.b,0): continue
			var point := Vector2(cell*32)+Vector2(16,16)
			var distance := point.distance_squared_to(route.points[-1]*32)
			if distance < nearest_interior:
				nearest_interior = distance
				destination = point
		var boundary := Vector2.ZERO
		var best := INF
		for cell in world.map.get_node("CaveFloor").get_used_cells():
			if world.map.cell_room(cell) != Vector2i(route.a,route.b): continue
			var point := Vector2(cell*32)+Vector2(16,16)
			var distance := point.distance_squared_to(destination)
			if distance < best:
				best = distance
				boundary = point
		await position(route.points[0]*32+Vector2(16,16),.6)
		await position(boundary,.6)
		var neighbor := probe(destination)
		var boundary_image := await frame()
		check(world.map.current_room == route.a and visible_sample(boundary_image,destination).b < .25,"entrance %d→%d hides neighboring interior"%[route.a,route.b])
		neighbor.queue_free()
	await position(Vector2(28,82)*32,.6)
	var visible := probe(Vector2(45,82)*32)
	var hidden := probe(Vector2(42,74)*32)
	var image := await frame()
	check(world.map.cell_room(Vector2i(hidden.position/32)).x == 10,"window clipping probe actually lies inside the hidden chamber")
	check(visible_sample(image,visible.position).r > .5,"Area 10 is visible through actual aperture")
	check(visible_sample(image,hidden.position).b < .25,"Area 10 outside aperture remains hidden")
	visible.queue_free()
	hidden.queue_free()
	await position(Vector2(28,82)*32)
	await capture("window")
	# A colored diagnostic above developer UI must still be desaturated.
	var ui := CanvasLayer.new()
	ui.layer = 115
	root.add_child(ui)
	var rect := ColorRect.new()
	rect.color = Color(.8,.15,.3)
	rect.position = Vector2(1140,180)
	rect.size = Vector2(32,32)
	ui.add_child(rect)
	await position(Plan.center(6)+Vector2(0,80))
	await create_timer(1.05).timeout
	check(gray_sample(await frame(),Vector2(1155,195)),"grayscale includes layers above HUD/dialogue/developer UI")
	var inventory_key := InputEventKey.new()
	inventory_key.keycode = KEY_SPACE
	inventory_key.pressed = true
	world.map_ui.handle_input(inventory_key)
	check(gray_sample(await frame(),Vector2(1155,195)),"inventory remains fully grayscale")
	world.map_ui.close_modals()
	world.map_ui.open_map()
	check(gray_sample(await frame(),Vector2(1155,195)),"map remains fully grayscale when terrain is hidden")
	world.map_ui.close_modals()
	session.developer_menu.show_menu()
	check(gray_sample(await frame(),Vector2(1155,195)),"paused developer overlay remains fully grayscale")
	session.developer_menu.close_menu()
	await position(Plan.center(7)+Vector2(0,80))
	check(not gray_sample(await frame(),Vector2(1155,195)),"Area 8 restores actual rendered color immediately")
	ui.queue_free()
	for setting in [{"size":Vector2i(1280,720),"zoom":1.0},{"size":Vector2i(1920,1080),"zoom":.75}]:
		root.size = setting.size
		await session.travel("underground_cave","FromFlooded")
		world = current_scene
		await position(Plan.ROUTES.filter(func(route): return route.b == 9)[0].points[-1]*32,setting.zoom)
		var camera: Camera2D = world.player.get_node("Camera2D")
		var view: Vector2 = world.get_viewport_rect().size/camera.zoom
		check(world.map.boss.position.x-50 > camera.get_screen_center_position().x+view.x*.5,"boss initially offscreen at "+str(setting))
		while not world.dialogue.active: await process_frame
		world.dialogue.advance()
		var center: Vector2 = camera.get_screen_center_position()
		check(world.player.position.x-32 > center.x-view.x*.5 and world.player.position.x < center.x-view.x*.25 and world.map.boss.position.x > center.x+view.x*.25 and camera.zoom == Vector2.ONE*setting.zoom,"camera shows both characters at opposite edges without changing zoom at "+str(setting))
		check(world.map.boss.position.x < Plan.room(9).rect.end.x*32-64,"Incarna remains within long room")
		await capture("intro-"+str(setting.size.x))
		world.dialogue.advance()
		while session.busy or current_scene == world: await process_frame
		await capture("incarna-"+str(setting.size.x))
		session.return_to_cave()
		while session.busy: await process_frame
	world = current_scene
	world.map_ui.open_map()
	await capture("underground-map")
	check(world.map_ui.full_map.shader.get_shader_parameter("atlas_size") == Vector2(Plan.SIZE*2),"map uses current cave dimensions")
	world.map_ui.close_modals()
	await session.travel("flooded_forest","FromCave")
	world = current_scene
	world.map_ui.open_map()
	check(world.map_ui.full_map.shader.get_shader_parameter("atlas_size") == Vector2(520,372),"forest map dimensions are unchanged")
	for voice in root.get_node("Music").get_children():
		if voice is AudioStreamPlayer: voice.stop()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("CAVE RENDER: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
