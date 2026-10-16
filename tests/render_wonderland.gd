extends SceneTree
const Plan = preload("res://scripts/wonderland/layout.gd")
var output := "/workspace/.catsSaga-validation/wonderland-render"
var failures := 0
func _initialize() -> void:
	create_timer(180).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func capture(name: String,point: Vector2) -> void:
	var world := current_scene
	world.player.position = point
	world.player.velocity = Vector2.ZERO
	var camera: Camera2D = world.player.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty(): failures += 1
	image.save_png(output.path_join(name+".png"))
	print("RENDER ",name)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session := root.get_node("Session")
	session.saves.save_path = "user://wonderland-render.json"
	session.story_flags["incarna_defeated"] = true
	session.story_flags["boss2_defeated"] = true
	await session.travel("flooded_forest","FromWonderland")
	await capture("pink-entrance-locked",Plan.FLOODED_DOOR+Vector2(0,144))
	session.story_flags[Plan.PINK_KEY] = true
	current_scene.map.get_node("WonderlandEntrance/PinkWonderlandDoor").handle_interaction(current_scene)
	await capture("pink-entrance-open",Plan.FLOODED_DOOR+Vector2(0,144))
	await create_timer(3.6).timeout
	for id in Plan.OUTDOORS:
		var scene: PackedScene = load("res://scenes/wonderland/"+id+".tscn")
		var probe := scene.instantiate()
		var marker: String = probe.get_node("Entries").get_child(0).name
		probe.free()
		await session.travel(id,marker)
		var point: Vector2 = {"wonderland_forest":Vector2(1280,1120),"tea_gardens":Vector2(1280,1000),"mushroom_thicket":Vector2(1320,1000),"royal_woods":Vector2(3070,650),"wonderland_village":Vector2(1920,1220),"queens_castle":Vector2(1280,920)}[id]
		await capture(id,point)
		if id == "wonderland_forest":
			await capture("great-tree",Vector2(1100,760))
			await capture("river-forest",Vector2(1100,440))
			var sign: Node = current_scene.map.get_node("Sign_To_mushroom_thicket")
			await capture("physical-sign",sign.position-Vector2(40,0))
			sign.handle_interaction(current_scene)
			await create_timer(1.5).timeout
			await capture("reading-sign",sign.position-Vector2(40,0))
			current_scene.dialogue._finish("")
			var options: AcceptDialog = load("res://scripts/ui/options_dialog.gd").new()
			current_scene.add_child(options)
			options.open()
			await capture("ambient-options",Vector2(1280,1120))
			options.hide()
			options.queue_free()
			current_scene.player.position = Vector2(1150,1120)
			var move := InputEventKey.new()
			move.keycode = KEY_D
			move.pressed = true
			Input.parse_input_event(move)
			Input.flush_buffered_events()
			await create_timer(.6).timeout
			move.pressed = false
			Input.parse_input_event(move)
			Input.flush_buffered_events()
			await capture("grounded-movement",current_scene.player.position)
		if id == "tea_gardens":
			await capture("giant-teapot",Vector2(760,1500))
			await capture("giant-teacup",Vector2(1720,1550))
			await capture("river-bridge",Vector2(1280,400))
		if id == "wonderland_village":
			for b in Plan.BUILDINGS: await capture("exterior-"+b.id,b.point+Vector2(0,70))
		if id == "queens_castle":
			session.map_reveal_cheat = true
			current_scene.map_ui.open_map()
			current_scene.map_ui.full_map.center_world = Vector2(240,180)
			current_scene.map_ui.full_map.zoom = 1.45
			current_scene.map_ui.target_zoom = 1.45
			await capture("wonderland-map",Vector2(1920,1728))
			current_scene.map_ui.close_modals()
			session.map_reveal_cheat = false
	for id in Plan.regions():
		if Plan.OUTDOORS.has(id): continue
		var marker := "FromVillage"
		if Plan.CASTLE_ROOMS.has(id): marker = "FromGrounds" if id == "castle_hall" else "From_castle_hall"
		await session.travel(id,marker)
		await capture(id,Vector2(640,500))
	await session.travel("underground_cave","FromFlooded")
	current_scene.map.current_room = 9
	await capture("incarna-key-chest",Plan.CHEST-Vector2(0,100))
	await session.main_menu()
	current_scene._show_info()
	current_scene._show_credits()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("creator-credits.png"))
	current_scene._open_asset_credits()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("asset-credits.png"))
	print("WONDERLAND RENDER: failures=",failures)
	quit(1 if failures else 0)
