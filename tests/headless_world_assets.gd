extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tileset := load("res://resources/world/forest_grass.tres") as TileSet
	var atlas := tileset.get_source(0) as TileSetAtlasSource
	check(tileset.tile_size == Vector2i(16, 16) and atlas.texture_region_size == Vector2i(16, 16), "TileSet and atlas use 16x16 grid")
	check(atlas.texture.resource_path == "res://assets/enironment/grass-tileset.png", "atlas references actual existing PNG without splitting")
	var grid := Vector2i(atlas.texture.get_size()) / 16
	check(atlas.get_tiles_count() == grid.x * grid.y, "entire atlas divided into grid cells")
	var every_cell := true
	for y in range(grid.y):
		for x in range(grid.x):
			every_cell = every_cell and atlas.has_tile(Vector2i(x, y))
	check(every_cell, "all atlas coordinates available for editor painting")
	check(tileset.get_physics_layers_count() == 0, "atlas has no solid decoration collision")
	check(tileset.get_patterns_count() == 1 and tileset.get_pattern(0).get_size() == Vector2i(3, 3), "connected cutout retained as complete 3x3 pattern")
	var pattern_ok := true
	for cell in tileset.get_pattern(0).get_used_cells():
		pattern_ok = pattern_ok and tileset.get_pattern(0).get_cell_atlas_coords(cell) == cell
	check(pattern_ok, "pattern retains original neighboring atlas coordinates")
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	var boss_sprite: Sprite2D = boss.get_node("Sprite2D")
	check(boss_sprite.texture.resource_path == "res://assets/bartboss.png", "battle still references existing Evil Bart artwork")
	check(boss_sprite.scale.x == boss_sprite.scale.y and is_equal_approx(boss_sprite.scale.x, 0.10603448), "boss aspect ratio preserved with original visual height")
	check(boss_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "boss uses nearest filtering")
	check(is_equal_approx(boss.get_node("CollisionShape2D").shape.radius, 74.02702) and boss.get_node("CollisionShape2D").position == Vector2(2, 1), "boss hitbox shape and placement unchanged")
	for name in ["forest_entrance", "deep_forest", "bart_area"]:
		var map: Node = load("res://scenes/world/" + name + ".tscn").instantiate()
		root.add_child(map)
		var ground: TileMapLayer = map.get_node("GrassGround")
		var details: TileMapLayer = map.get_node("GrassDetails")
		check(not map.has_node("BackgroundPlaceholder"), name + " replaces solid grass placeholder")
		check(ground.tile_set == tileset and details.tile_set == tileset, name + " layers share editable external TileSet")
		check(ground.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and details.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, name + " layers use nearest filtering")
		check(not ground.collision_enabled and not details.collision_enabled and not ground.navigation_enabled and not details.navigation_enabled, name + " grass and flowers do not block movement")
		check(ground.get_used_rect() == Rect2i(Vector2i.ZERO, Vector2i(ceili(map.map_size.x / 16), ceili(map.map_size.y / 16))), name + " ground covers entire existing map")
		var ground_ok := true
		for cell in ground.get_used_cells():
			ground_ok = ground_ok and ground.get_cell_atlas_coords(cell) in [Vector2i(3, 1), Vector2i(3, 0), Vector2i(3, 2)]
		check(ground_ok, name + " ground uses only appropriate single-cell grass")
		check(details.get_used_cells().size() > 0 and details.get_used_cells().size() <= 12, name + " sparse authored details avoid filling map with every atlas tile")
		var placement_ok := true
		var path: TileMapLayer = map.get_node("Paths")
		for cell in details.get_used_cells():
			var point := Vector2(cell * 16) + Vector2(8, 8)
			placement_ok = placement_ok and path.get_cell_source_id(cell) == -1
			for obstacle in map.get_node("Obstacles").get_children():
				var shape: RectangleShape2D = obstacle.get_node("CollisionShape2D").shape
				placement_ok = placement_ok and not Rect2(obstacle.position - shape.size / 2, shape.size).has_point(point)
		check(placement_ok, name + " decorative patches placed away from existing paths and obstacles")
		check(ground.z_index < details.z_index and details.z_index < path.z_index, name + " paths and entities remain above grass")
		check(map.get_node("Obstacles").get_child_count() == 4 and map.has_node("Portals") and map.has_node("Entries"), name + " existing collision and travel nodes retained")
		if name == "bart_area":
			var npc: Node = map.get_node("Characters/EvilBart")
			var sprite: Sprite2D = npc.get_node("Sprite2D")
			check(sprite.texture == boss_sprite.texture, "NPC and boss use same loaded texture resource")
			check(sprite.scale.x == sprite.scale.y and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "NPC uses uniform scale and nearest filtering")
			check(sprite.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "shared texture retains transparency")
			check(npc.position == Vector2(1000, 450) and npc.interaction_radius == 100 and npc.starts_battle and npc.dialogue_id == "bart_encounter", "Bart location and interaction settings preserved")
			check(npc.get_script() != boss.get_script(), "NPC and boss retain separate gameplay scripts")
		# Resource packing mirrors saving an edited layer in the Godot editor.
		ground.set_cell(Vector2i(1, 1), 0, Vector2i(4, 0))
		var packed := PackedScene.new()
		check(packed.pack(map) == OK, name + " painted layers can be saved as scene data")
		var copy: Node = packed.instantiate()
		check(copy.get_node("GrassGround").get_cell_atlas_coords(Vector2i(1, 1)) == Vector2i(4, 0), name + " manual tile painting survives scene reload")
		copy.free()
		map.free()
	boss.free()
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "overworld resolution remains 1280x720")
	print("WORLD ASSET VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
