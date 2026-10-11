extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func connected(paths: TileMapLayer) -> Dictionary:
	var pending: Array[Vector2i] = [paths.get_used_cells()[0]]
	var seen := {pending[0]: true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + step
			if not seen.has(neighbor) and paths.get_cell_source_id(neighbor) != -1:
				seen[neighbor] = true
				pending.append(neighbor)
	return seen

func run() -> void:
	var tree_scene: PackedScene = load("res://scenes/world/tree.tscn")
	for filename in ["forest_entrance", "deep_forest", "bart_area"]:
		var map: Node2D = load("res://scenes/world/" + filename + ".tscn").instantiate()
		root.add_child(map)
		await physics_frame
		await physics_frame
		var paths: TileMapLayer = map.get_node("Paths")
		var reachable := connected(paths)
		check(reachable.size() == paths.get_used_cells().size(), filename + " winding routes and optional clearings form one connected network")
		var soil_only := true
		var route_clear := true
		var body := RectangleShape2D.new()
		body.size = Vector2(28, 28)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = body
		query.collision_mask = 1
		for cell in paths.get_used_cells():
			soil_only = soil_only and paths.get_cell_atlas_coords(cell).x == 6
			query.transform = Transform2D(0, paths.map_to_local(cell))
			# Leave the outermost edge of painted paths for natural terrain borders.
			var interior := true
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				interior = interior and reachable.has(cell + step)
			if interior:
				route_clear = route_clear and map.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
		check(soil_only, filename + " uses existing single-cell soil tiles")
		check(route_clear, filename + " interior path cells fit actual player collision shape")
		var important_clear := true
		for group in ["Entries", "Portals"]:
			for marker in map.get_node(group).get_children():
				important_clear = important_clear and reachable.has(paths.local_to_map(marker.position))
		check(important_clear, filename + " every entrance and exit connects to the route network")
		var bands := [0, 0, 0]
		var tree_ok := true
		var canopy_clear := true
		var repeated := true
		var landmarks_clear := true
		for tree in map.get_node("Trees").get_children():
			var factor: float = tree.get_size_multiplier()
			bands[0 if factor < 0.9 else (1 if factor <= 1.2 else 2)] += 1
			var sprite: Sprite2D = tree.get_node("Sprite2D")
			var shape: CapsuleShape2D = tree.get_node("CollisionShape2D").shape
			tree_ok = tree_ok and factor >= 0.7 and factor <= 1.5 and sprite.scale.x == sprite.scale.y and sprite.texture.resource_path == "res://assets/enironment/tree.png" and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and is_equal_approx(shape.radius, 8 * factor) and is_equal_approx(shape.height, 24 * factor)
			var rect := Rect2(tree.position + sprite.position, sprite.texture.get_size() * sprite.scale)
			for cell in paths.get_used_cells():
				canopy_clear = canopy_clear and not rect.intersects(Rect2(Vector2(cell * 16), Vector2(16, 16)))
			var copy: Node = tree_scene.instantiate()
			copy.variation_seed = tree.variation_seed
			repeated = repeated and is_equal_approx(copy.get_size_multiplier(), factor)
			copy.free()
			if factor >= 1.25:
				for marker in map.get_node("Discoveries").get_children():
					landmarks_clear = landmarks_clear and not rect.grow(32).has_point(marker.position)
		check(tree_ok, filename + " uniformly scaled original trees have scaled trunk capsules")
		check(bands[0] > 0 and bands[2] > 0 and bands[1] > bands[0] and bands[1] > bands[2], filename + " mixes sizes with medium most common: " + str(bands))
		check(repeated, filename + " sizes survive reinstantiation with serialized seeds")
		check(canopy_clear, filename + " full tree canopies leave painted routes unobstructed")
		check(landmarks_clear, filename + " larger trees leave reserved grassy clearings open")
		check(map.y_sort_enabled and map.get_node("Trees").y_sort_enabled and map.get_node("Characters").y_sort_enabled, filename + " tree trunks and characters share Y-sorting")
		if filename == "deep_forest":
			check(map.map_size == Vector2(5120,2880) and map.get_node("Trees").get_child_count() >= 180, "Deep Forest expands physically and more than triples the previous 62 trees")
			check(paths.get_cell_source_id(Vector2i(120,33)) == -1 and reachable.has(Vector2i(77,74)), "Deep Forest replaces former east-west corridor with distant southern winding route")
		map.free()
	var tree: Node = tree_scene.instantiate()
	var other: Node = tree_scene.instantiate()
	root.add_child(tree)
	root.add_child(other)
	var seeded: float = tree.get_size_multiplier()
	tree.size_override = 1.5
	check(is_equal_approx(tree.get_node("Sprite2D").scale.y * tree.get_node("Sprite2D").texture.get_height(), 210) and tree.trunk_shape.radius == 12 and tree.trunk_shape.height == 36, "Inspector override updates both artwork and trunk immediately")
	check(tree.trunk_shape != other.trunk_shape and other.trunk_shape.radius != 12, "resizing one tree never changes another tree's collider")
	tree.size_override = 0
	check(is_equal_approx(tree.get_size_multiplier(), seeded), "removing manual override restores stable seeded size")
	tree.free()
	other.free()
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-forest-overhaul.json"
	await session.new_game()
	var world: Node = current_scene
	var blocked: Vector2 = world.map.get_node("Trees").get_child(0).position + Vector2(0, -8)
	session.story_flags["validation_preserved"] = true
	session.saves.write_save(session.snapshot("entrance", blocked))
	await session.load_game()
	await physics_frame
	await physics_frame
	await process_frame
	world = current_scene
	check(not world.checking_spawn and world.player.position == world.map.get_node("Entries/" + session.entry_marker).position, "blocked old save safely falls back to an existing entrance")
	check(session.story_flags.get("validation_preserved", false), "collision fallback preserves progression flags")
	var safe := Vector2(280, 450)
	session.saves.write_save(session.snapshot("entrance", safe))
	await session.load_game()
	await physics_frame
	await physics_frame
	await process_frame
	check(current_scene.player.position == safe and not current_scene.checking_spawn, "valid saved position is retained")
	await session.travel("deep_forest", "FromBart")
	var expanded_spawn := Vector2(2280,1200)
	check(current_scene.player.position == expanded_spawn and current_scene.player.get_node("Camera2D").limit_right == 5120 and current_scene.player.get_node("Camera2D").limit_bottom == 2880, "relocated Deep Forest arrival and camera follow expanded bounds")
	check(session.saves.write_save(session.snapshot("deep_forest", expanded_spawn)), "version-one save accepts new Deep Forest coordinates")
	await session.load_game()
	await physics_frame
	await physics_frame
	check(current_scene.player.position == expanded_spawn, "expanded-area saved position survives real scene reload")
	print("FOREST OVERHAUL VALIDATION: ", checks, " checks, ", failures, " failures")
	# Allow the audio server to retire looping playback before test shutdown.
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
