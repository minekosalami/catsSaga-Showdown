extends "res://tests/render_forest_combat_overhaul.gd"
## Real rendered environment comparisons; screenshots are QA output, not assets.
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	await session.new_game()
	for view in [
		["entrance",Vector2(1500,1050),"entrance"],
		["deep_forest",Vector2(1150,700),"deep-forest-clearing"],
		["deep_forest",Vector2(3400,1750),"deep-forest-grove"],
		["bart_area",Vector2(1792,1000),"bart-area"],
		["flooded_forest",Vector2(1968,816),"flooded-crossing"],
		["flooded_forest",Vector2(3150,900),"flooded-boss"],
		["flooded_forest",Vector2(3456,2144),"flooded-pond-bridge"]]:
		await forest(view[0],view[1],view[2])
	await session.travel("deep_forest","Start")
	for tree in get_nodes_in_group("journey_trees"):
		if not current_scene.map.is_ancestor_of(tree) or tree.position.x<800 or tree.position.y<500:continue
		var front: Vector2=tree.position+Vector2(0,72)
		var obstructed := false
		for other in get_nodes_in_group("journey_trees"):
			if other==tree or other.position.y<front.y:continue
			var picture: Sprite2D=other.get_node("Sprite2D")
			var extent: Vector2=picture.texture.get_size()*picture.scale
			if Rect2(other.position+picture.position-extent*.5,extent).grow(24).has_point(front):obstructed=true;break
		if obstructed:continue
		for offset in [-66,72]:
			current_scene.player.position=tree.position+Vector2(0,offset)
			var camera: Camera2D=current_scene.player.get_node("Camera2D")
			camera.lead=Vector2.ZERO
			camera.followed=current_scene.player.position
			camera.global_position=camera.followed
			camera.force_update_scroll()
			await create_timer(.15).timeout
			await snapshot("canopy-behind" if offset<0 else "canopy-front")
		break
	# Load after autoload registration when this file is a --script MainLoop.
	var saves: Dictionary=load("res://scripts/world/save_statue.gd").get_script_constant_map().LOCATIONS
	for area: String in saves:
		for index in saves[area].size():
			await forest(area,saves[area][index]+Vector2(0,58),"save-star-"+area+"-"+str(index))
	session.map_reveal_cheat = true
	current_scene.map_ui.open_map()
	await snapshot("world-map")
	current_scene.map_ui.close_modals()
	root.get_node("Music").play_theme("")
	print("ENVIRONMENT CAPTURE COMPLETE")
	quit()
