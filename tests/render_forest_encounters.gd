extends SceneTree
var selected:=-1
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	run.call_deferred()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/forest-encounters/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	var session=root.get_node("Session")
	await session.new_game(3)
	session.story_flags["blankkitten_defeated"]=true
	selected=-1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemy-kind="):selected=int(arg.trim_prefix("--enemy-kind="))
	for area in (["entrance","deep_forest","bart_area","flooded_forest"] if selected<0 else []):
		await session.travel(area,"Start")
		var world=current_scene
		while not world.encounters.loaded:await process_frame
		var point:Vector2={"entrance":Vector2(2635,970),"deep_forest":Vector2(3104,1820),"bart_area":Vector2(1568,1094),"flooded_forest":Vector2(1936,850)}[area]
		world.player.position=point
		world.player.get_node("Camera2D").reset_smoothing()
		session.weather.set_weather("clear")
		for i in 150:session.weather._process(.2)
		await create_timer(.3).timeout
		await capture(area+"-clear")
		session.weather.set_weather("heavy_rain")
		for i in 100:session.weather._process(.2)
		await create_timer(.3).timeout
		await capture(area+"-rain")
		world.encounters.set_process(false)
	for kind in ([selected] if selected>=0 else []):
		session.forest_encounters.active={"kind":kind}
		await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
		var battle=current_scene.battle
		battle.player.invincible=true
		battle.boss.firing_timer=.1
		await create_timer(4).timeout
		await capture("enemy-%d"%kind)
	quit()
