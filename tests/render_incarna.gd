extends SceneTree
const Cfg = preload("res://scripts/incarna/config.gd")
var game: Node
var checks := 0
var failures := 0
var output := "/workspace/.catsSaga-validation/incarna-render"
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func frame(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(not picture.is_empty(),name+" renders")
	picture.save_png(output.path_join(name+".png"))
	return picture
func sample(time: float) -> void:
	game.timeline.reset_clock(time)
	game.update_clock(time)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-incarna-render.json"
	await session.transition_to("res://scenes/incarna/combat_host.tscn",true)
	game = current_scene.battle
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.timeline.set_physics_process(false)
	game.music_player.stop()
	for time in [0.0,2.5,5.0,7.5,10.0]:
		sample(time)
		await frame("emergence-"+str(time))
		check(game.player.entrance_locked == (time < 10),"emergence lock matches rendered pose")
	sample(30)
	var normal := await frame("looming-creature")
	var bright := 0
	var gray := 0
	for y in range(0,410,8):
		for x in range(60,1220,8):
			var pixel := normal.get_pixel(x,y)
			if pixel.r > .3 and pixel.g > .3 and pixel.b > .3:
				bright += 1
				if absf(pixel.r-pixel.g) < .03 and absf(pixel.g-pixel.b) < .03: gray += 1
	check(bright > 600 and gray > bright*.92,"large original creature renders monochrome across top")
	check(normal.get_pixel(20,650).v < .08,"lower playfield background stays dark")
	for i in range(10):
		sample(12.0+i*.25)
		await frame("reconnect-%02d"%i)
		check(game.rig.cables.size() == 7,"parts retain structural tethers while exchanging sockets")
	sample(41.14)
	game.timeline.issue({"time":41.14,"kind":"paw","section":3,"index":0})
	game.timeline.issue({"time":41.14,"kind":"zone","section":3,"index":0})
	for i in range(22):
		game.update_clock(41.14+i*.13)
		await frame("lunge-%02d"%i)
	sample(82.28)
	for i in range(21):
		game.player.position.x = 320+i*25
		game.update_clock(82.28+i*.1)
		if i%4 == 0: await frame("barrage-%02d"%i)
	check(game.timeline.shots.any(func(s: Dictionary): return s.kind == "spear"),"original spear art is active during peak barrage")
	sample(82.34)
	await frame("returning-beat")
	sample(60)
	await frame("psychedelic-pressure")
	game.reduced_effects = true
	game.update_clock(60)
	await frame("reduced-fx")
	check(game.atmosphere.material.get_shader_parameter("strength") == 0,"Reduced FX removes interference")
	game.reduced_effects = false
	root.size = Vector2i(1920,1080)
	await process_frame
	sample(50)
	await frame("large-window")
	check(current_scene.arena.size == Cfg.SIZE,"larger window retains wide internal arena")
	root.size = Vector2i(1280,720)
	await process_frame
	game.player.health = 3
	game.update_clock(Cfg.END)
	await create_timer(.8).timeout
	await frame("endured")
	check(game.ui.return_button.is_visible_in_tree(),"victory exposes cave return")
	await session.main_menu()
	print("INCARNA RENDER: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
