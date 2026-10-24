extends SceneTree
const OUTPUT := "res://docs/review/alive-ui/"
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or DisplayServer.get_name()=="headless":quit(1);return
	run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(1280,720)
	var session: Node=root.get_node("Session")
	await session.transition_to("res://scenes/main_menu.tscn")
	await create_timer(.35).timeout
	await shot("main-menu")
	await session.new_game(3)
	for id in session.rpg.ITEMS:session.rpg.inventory[id]=3
	session.forest_encounters.active={"id":0,"kind":0,"area":"entrance","position":Vector2(240,912),"settled":false}
	session.forest_encounters.population[0]={"alive":true,"kind":0,"position":Vector2(1000,912),"home":Vector2(1000,912),"retreat":false,"ignore_until":0.0}
	await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
	var battle: Node=current_scene.battle
	battle.player.invincible=true
	await create_timer(1).timeout
	await shot("ordinary-battle")
	var alt := InputEventKey.new();alt.keycode=KEY_ALT;alt.pressed=true
	Input.parse_input_event(alt)
	await create_timer(.2).timeout
	await shot("ordinary-items")
	battle.boss.take_damage(72)
	await create_timer(2.3).timeout
	await shot("victory-S-plus")
	current_scene.rpg_ui.close_results()
	await process_frame
	while session.busy:await process_frame
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		session.area_id=area;session.forest_encounters.active={"kind":2,"area":area}
		await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
		battle=current_scene.battle;battle.player.invincible=true
		battle.boss.firing_timer=.1
		await create_timer(1.4).timeout
		await shot("region-"+area)
		if area=="deep_forest":
			var live: Node=current_scene.rpg_ui
			live.score.finished=true;live.score.elapsed=10;live.score.streak=0;live.score.completed_squares=82;live.score.hits=1
			await create_timer(.25).timeout
			await shot("live-grade-A")
	for id in ["bart","boss2","blankkitten"]:
		var path: String="res://scenes/combat_host.tscn" if id=="bart" else "res://scenes/%s/combat_host.tscn"%id
		await session.transition_to(path,true)
		battle=current_scene.battle;battle.player.invincible=true
		if id=="bart":battle.music_player.seek(7)
		if id=="blankkitten":battle.music_player.seek(12)
		await create_timer(.5).timeout
		await shot(id+"-items-status")
	await session.main_menu()
	current_scene._show_records()
	await create_timer(.3).timeout
	await shot("records")
	await session.travel("deep_forest","Start")
	var shop: Node=load("res://scripts/story/shop_screen.gd").new()
	shop.world=current_scene;current_scene.add_child(shop)
	current_scene.dialogue._finish("shop_buy")
	await process_frame;await process_frame
	current_scene.dialogue.advance();current_scene.dialogue.advance()
	await create_timer(.3).timeout
	await shot("shop-consumables")
	shop.close();await process_frame
	await shot("overworld-hud")
	session.show_notification("3/10 feathers collected!","FeatherNotification")
	await create_timer(.25).timeout
	await shot("collectible-toast")
	session.open_pause();await process_frame
	await shot("pause")
	session.close_pause()
	quit()
