extends SceneTree
## Native renderer; screenshots are evidence, never runtime artwork.
var output := "res://docs/review/forest-chapter"
var combat_only := false
var selected_kind := -1
var selected_area := ""
const VIEWS := {
	"entrance": [Vector2(640,1168),Vector2(2635,970)],
	"deep_forest": [Vector2(2590,1000),Vector2(3104,1820)],
	"bart_area": [Vector2(1568,1094),Vector2(2110,1320)],
	"flooded_forest": [Vector2(1936,850),Vector2(3456,2144)]}
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--combat-only":combat_only=true
		if arg.begins_with("--kind="):selected_kind=int(arg.trim_prefix("--kind="))
		if arg.begins_with("--area="):selected_area=arg.trim_prefix("--area=")
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output+"/"+label+".png")
	if error!=OK:push_error("Capture failed: "+label);quit(1)
func run() -> void:
	root.size=Vector2i(1280,720)
	var session=root.get_node("Session")
	await session.new_game(3)
	session.story_flags["blankkitten_defeated"]=true
	session.forest_encounters.protection_until=INF
	if combat_only:
		await combat_views(session)
		await session.main_menu()
		quit();return
	var metrics: Dictionary={}
	if FileAccess.file_exists(output+"/benchmark.json"):
		metrics=JSON.parse_string(FileAccess.get_file_as_string(output+"/benchmark.json"))
	for area in VIEWS:
		if not selected_area.is_empty() and area!=selected_area:continue
		await session.travel(area,"Start")
		var world=current_scene
		while not world.encounters.loaded:await process_frame
		world.encounters.set_process(false)
		for actor in world.encounters.actors:actor.set_physics_process(false)
		session.weather.set_weather("clear")
		for i in 150:session.weather._process(.2)
		for i in VIEWS[area].size():
			world.player.position=VIEWS[area][i]
			world.player.get_node("Camera2D").reset_smoothing()
			await create_timer(.35).timeout
			await capture(area+"-"+str(i))
		var intervals: Array[float]=[]
		var last:=Time.get_ticks_usec()
		for i in 90:
			await process_frame
			var now:=Time.get_ticks_usec();intervals.append((now-last)/1000.0);last=now
		intervals.sort()
		metrics[area]={"median_ms":intervals[45],"p95_ms":intervals[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
		if area=="flooded_forest":
			session.weather.set_weather("heavy_rain")
			for i in 100:session.weather._process(.2)
			await create_timer(.3).timeout
			await capture("flooded-rain")
		# Standalone scene overview uses the same baked TileMapLayers and scenery.
		var view:=SubViewport.new();view.size=Vector2i(world.map.map_size/4);view.disable_3d=true
		view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
		var map=load(preload("res://scripts/journey/layout.gd").scene(area)).instantiate();view.add_child(map)
		load("res://scripts/story/world_content.gd").install_map(map,area)
		load("res://scripts/world/save_statue.gd").install(map)
		var camera:=Camera2D.new();camera.position=map.map_size*.5;camera.zoom=Vector2.ONE*.25;view.add_child(camera);camera.make_current()
		await process_frame;await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(output+"/"+area+"-overview.png")
		view.queue_free();await process_frame
	FileAccess.open(output+"/benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	await session.main_menu()
	quit()

func combat_views(session: Node) -> void:
	for kind in 8:
		if selected_kind>=0 and kind!=selected_kind:continue
		session.forest_encounters.active={"kind":kind,"area":preload("res://scripts/journey/layout.gd").ORDER[kind%4]}
		await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
		var battle=current_scene.battle
		battle.player.invincible=true
		battle.boss.rng.seed=8351+kind
		await create_timer(3.2).timeout
		await capture("projectiles-%d"%kind)
		if kind==3:
			var bullet=load("res://scenes/enemybullet.tscn").instantiate()
			bullet.set_script(load("res://scripts/encounters/projectile.gd"))
			bullet.theme=3;bullet.bullet_color=battle.Catalog.COLORS[3]
			bullet.position=battle.player.get_node("CollisionShape2D").global_position+Vector2(80,-40)
			bullet.speed=0;battle.add_child(bullet)
			await capture("close-spawn-warning")
