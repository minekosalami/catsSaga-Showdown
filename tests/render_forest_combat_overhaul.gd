extends SceneTree
const Plan = preload("res://scripts/journey/layout.gd")
var directory := OS.get_temp_dir().path_join("catsSaga-overhaul-review")
var session: Node
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(180).timeout.connect(func():quit(1))
	run.call_deferred()
func snapshot(name: String,internal := false) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	if internal:current_scene.arena.get_texture().get_image().save_png(directory.path_join(name+"-arena.png"))
	print("RENDER: ",name," save=",result)
func forest(area: String,point: Vector2,label: String) -> void:
	await session.travel(area,"Start")
	if label=="flooded-crossing":
		var bridge: TileMapLayer = current_scene.map.get_node("Bridges")
		# Select the crossing closest to the requested river view, keeping the
		# player on an actual dry, non-solid bridge cell in the review capture.
		var wanted := point
		var best := INF
		for cell in bridge.get_used_cells():
			var candidate := bridge.to_global(bridge.map_to_local(cell))
			if candidate.distance_to(wanted)<best:best = candidate.distance_to(wanted);point = candidate
	current_scene.player.position = point
	current_scene.player.get_node("Camera2D").reset_smoothing()
	current_scene.player.get_node("Camera2D").force_update_scroll()
	await create_timer(.15).timeout
	await snapshot(label)
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://render-overhaul.json"
	await session.new_game()
	await forest("entrance",Vector2(1500,1050),"entrance")
	await forest("deep_forest",Vector2(1150,700),"deep-forest-clearing")
	await forest("deep_forest",Vector2(3400,1750),"deep-forest-grove")
	var tree: Node2D
	var trees := get_nodes_in_group("journey_trees")
	for candidate in trees:
		if not current_scene.map.is_ancestor_of(candidate) or candidate.position.x<800 or candidate.position.y<500:continue
		var front: Vector2 = candidate.position+Vector2(0,50)
		var obstructed := false
		for other in trees:
			if other==candidate or other.position.y<front.y:continue
			var sprite: Sprite2D = other.get_node("Sprite2D")
			var extent: Vector2 = sprite.texture.get_size()*sprite.scale
			if Rect2(other.position+sprite.position-extent*.5,extent).grow(28).has_point(front):obstructed = true;break
		if not obstructed:
			tree = candidate
			break
	if tree != null:
		for offset in [-42,50]:
			current_scene.player.position = tree.position+Vector2(0,offset)
			current_scene.player.get_node("Camera2D").reset_smoothing()
			current_scene.player.get_node("Camera2D").force_update_scroll()
			await create_timer(.08).timeout
			await snapshot("canopy-behind" if offset<0 else "canopy-front")
	await forest("bart_area",Vector2(1792,1000),"bart-area")
	await forest("flooded_forest",Vector2(1968,816),"flooded-crossing")
	await forest("flooded_forest",Vector2(3150,900),"flooded-boss")
	session.map_reveal_cheat = true
	current_scene.map_ui.open_map()
	await snapshot("world-map")
	current_scene.map_ui.close_modals()
	for encounter in [["bart","res://scenes/combat_host.tscn"],["boss2","res://scenes/boss2/combat_host.tscn"],["blankkitten","res://scenes/blankkitten/combat_host.tscn"]]:
		session.encounter_id = encounter[0]
		await session.transition_to(encounter[1],true)
		var battle: Node = current_scene.battle
		battle.player.invincible = true
		if encounter[0]=="bart":
			battle.music_player.seek(8)
			await create_timer(.6).timeout
			await snapshot("bart-opening",true)
			battle.music_player.seek(92)
			await create_timer(.8).timeout
			await snapshot("bart-climax",true)
		elif encounter[0]=="boss2":
			battle.music_player.seek(42)
			await create_timer(.6).timeout
			await snapshot("doppelcat-lasers",true)
			battle.music_player.seek(82)
			await create_timer(.6).timeout
			await snapshot("doppelcat-cross",true)
			battle.set_physics_process(false)
			battle.timeline.advance(100.0)
			battle.timeline.clear_hostiles()
			battle.ui.update(100.0)
			battle.elapsed_time = 100.0
			battle.get_node("SurrealDirector").update_clock(100.0)
			for index in range(240):
				var bullet: Area2D = load("res://scenes/boss2/projectile.tscn").instantiate()
				bullet.position = Vector2(30+(index%16)*32,330+(index/16)*32)
				bullet.visual_style = index%4
				bullet.bullet_color = Color("#83e6ff") if index%2 else Color("#ff89c7")
				battle.add_child(bullet)
				bullet.set_physics_process(false)
			await snapshot("doppelcat-projectile-stress",true)
		else:
			for shot in [[36.0,"sequence-fireball"],[72.0,"sequence-grid"],[110.0,"sequence-showdown"]]:
				battle.seek_timestamp(shot[0])
				battle.development_run = false
				await create_timer(.5).timeout
				await snapshot(shot[1],true)
		root.get_node("VisualSettings").reduced = true
		await create_timer(.2).timeout
		await snapshot(encounter[0]+"-reduced",true)
		root.get_node("VisualSettings").reduced = false
		await session.main_menu()
	session.open_options()
	await create_timer(.15).timeout
	await snapshot("options")
	root.get_node("Music").play_theme("")
	await process_frame
	print("RENDER COMPLETE")
	quit()
