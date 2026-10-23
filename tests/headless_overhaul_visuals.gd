extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	create_timer(60).timeout.connect(func():quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func run() -> void:
	var session: Node = root.get_node("Session")
	var options: Node = root.get_node("VisualSettings")
	session.saves.save_path = "user://overhaul-visuals.json"
	await session.new_game()
	await session.travel("bart_area","Start")
	await session.begin_battle(Vector2(1792,1000))
	var battle: Node = current_scene.battle
	var director: Node = battle.get_node("SurrealDirector")
	check(not director.reactive_enabled and not director.material_fx.get_shader_parameter("boss_active"),"regular opening has no advanced music reaction")
	check(battle.music_player.bus=="Master","regular music stays on original route")
	check(director.view.size==Vector2i(270,450),"normal background is rendered efficiently at half resolution")
	check(not battle.get_node("CinematicArena").environment.visible,"replaced environment does not submit hidden GFX art")
	battle.music_player.seek(7.0)
	await create_timer(.25).timeout
	check(director.reactive_enabled and director.analyzer!=null,"boss alone enables FFT analysis")
	check(battle.music_player.bus=="BossMusic" and AudioServer.get_bus_send(AudioServer.get_bus_index("BossMusic"))=="Master","boss analysis routes at unity to Master")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BossMusic"))==0.0,"analysis does not change normalized loudness")
	check(absf(director.clock-battle.elapsed_time)<.04,"visuals observe the authoritative audio clock")
	battle.music_player.seek(21.0)
	await create_timer(.3).timeout
	check(director.bass>0.0 or director.detail>0.0,"real music reaches the analyzer")
	var radius: float = battle.player.get_node("CollisionShape2D").shape.radius
	var health: int = battle.player.health
	options.set_reduced(true)
	options.set_motion(0)
	await create_timer(.15).timeout
	check(director.view.size==Vector2i(135,225) and director.material_fx.get_shader_parameter("motion")==0.0,"reduced FX quarters rendering and motion can stop")
	check(battle.player.health==health and battle.player.get_node("CollisionShape2D").shape.radius==radius,"effects settings never alter player health or hitbox")
	var config := ConfigFile.new()
	check(config.load(options.PATH)==OK and config.get_value("visuals","reduced",false),"effects option persists independently of game saves")
	options.set_reduced(false)
	options.set_motion(.8)
	for style in range(4):
		var bullet: Area2D = load("res://scenes/enemybullet.tscn").instantiate()
		bullet.visual_style = style
		bullet.speed = 0
		bullet.position = Vector2(60,100)
		battle.add_child(bullet)
		check(bullet.body_radius==bullet.RADII[style] and bullet.get_node("CollisionShape2D").shape.radius==bullet.RADII[style],"human projectile style preserves collision radius "+str(style))
		bullet.queue_free()
	await session.main_menu()
	session.encounter_id = "blankkitten"
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	battle = current_scene.battle
	check(battle.get_node("SurrealDirector").identity==2,"Sequence has its own folded-space identity")
	check(battle.presentation.background_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"replaced Sequence shader passes do not keep rendering")
	check(battle.hazards.ball_material.get_shader_parameter("human_core").resource_path.ends_with("nova_00.png"),"Sequence fireball uses original human pixel artwork")
	check(battle.Cue.END==145.71 and battle.player.health==5,"Sequence duration remains exact")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("OVERHAUL VISUALS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
