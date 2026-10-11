extends SceneTree

## Regenerate after editing level geometry. No playable scenes are duplicated.
const Layout = preload("res://scripts/maps/world_layout.gd")
var atlas: Image
var source_images := {}
var tile_colors := {}
var source_hashes := {}
var boss_locations := {}

func _initialize() -> void:
	call_deferred("run")

func image_for(texture: Texture2D) -> Image:
	var key := texture.resource_path
	if not source_images.has(key): source_images[key] = texture.get_image()
	return source_images[key]

func average_tile(layer: TileMapLayer, cell: Vector2i) -> Color:
	var source_id := layer.get_cell_source_id(cell)
	var coordinate := layer.get_cell_atlas_coords(cell)
	var source: TileSetAtlasSource = layer.tile_set.get_source(source_id)
	var key := str(source.texture.resource_path)+str(coordinate)
	if tile_colors.has(key): return tile_colors[key]
	var pixels := image_for(source.texture)
	var rect := source.get_tile_texture_region(coordinate)
	var result := Color(0,0,0,0)
	var count := 0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var color := pixels.get_pixel(x,y)
			if color.a > 0.5:
				result += color
				count += 1
	result = result/float(maxi(count,1))
	result.a = 1
	tile_colors[key] = result
	return result

func ellipse(center: Vector2, radii: Vector2, offset: Vector2i, color: Color, size: Vector2i) -> void:
	for y in range(maxi(0,int(center.y-radii.y)),mini(size.y-1,int(center.y+radii.y))+1):
		for x in range(maxi(0,int(center.x-radii.x)),mini(size.x-1,int(center.x+radii.x))+1):
			if ((Vector2(x+0.5,y+0.5)-center)/radii).length_squared() <= 1:
				atlas.set_pixelv(offset+Vector2i(x,y),color)

func run() -> void:
	atlas = Image.create(Layout.SIZE.x,Layout.SIZE.y,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for area in Layout.REGIONS:
		var region: Dictionary = Layout.REGIONS[area]
		var offset: Vector2i = region.offset
		var size: Vector2i = region.size
		var map: Node2D = load("res://scenes/world/"+region.scene+".tscn").instantiate()
		var scene_path: String = "res://scenes/world/"+region.scene+".tscn"
		source_hashes[scene_path] = FileAccess.get_sha256(scene_path)
		root.add_child(map)
		var boss := map.get_node_or_null("Characters/" + ("EvilBart" if area == "bart_area" else "Boss2NPC"))
		if area in ["bart_area", "flooded_forest"] and boss != null:
			boss_locations["bart" if area == "bart_area" else "boss2"] = {"area":area, "local_position":boss.position}
		var ground: TileMapLayer = map.get_node("GrassGround")
		for cell in ground.get_used_cells():
			var color := average_tile(ground,cell)*ground.modulate*map.modulate
			atlas.set_pixelv(offset+cell,color)
		var layers := map.get_children().filter(func(node: Node): return node is TileMapLayer and node != ground)
		layers.sort_custom(func(a: Node, b: Node): return a.z_index < b.z_index)
		for layer in layers:
			if layer.name == "GFXForestFloor":
				for cell in layer.get_used_cells():
					var current := atlas.get_pixelv(offset+cell)
					atlas.set_pixelv(offset+cell,current.lerp(average_tile(layer,cell)*map.modulate,layer.modulate.a))
			elif layer.name.contains("Water") or layer.name in ["Paths","WindingTrails"]:
				for cell in layer.get_used_cells():
					var color := Color("#3785a6") if layer.name.contains("Water") else average_tile(layer,cell)*map.modulate
					atlas.set_pixelv(offset+cell,color)
			elif layer.name.begins_with("GFXTrees") or layer.name == "GFXBoulders":
				for cell in layer.get_used_cells():
					var source: TileSetAtlasSource = layer.tile_set.get_source(layer.get_cell_source_id(cell))
					var native_size := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell)).size
					var extent: Vector2 = Vector2(native_size)*layer.scale/16.0
					var color := Color("#344e35") if layer.name.begins_with("GFXTrees") else Color("#847d68")
					ellipse(layer.map_to_local(cell)*layer.scale/16.0,extent*0.45,offset,color,size)
		for tree in get_nodes_in_group("world_trees"):
			if not map.is_ancestor_of(tree): continue
			var sprite: Sprite2D = tree.get_node("Sprite2D")
			var extent := sprite.texture.get_size()*sprite.scale/16.0
			var center: Vector2 = (tree.global_position+sprite.position)/16.0+extent/2
			ellipse(center,extent*0.45,offset,Color("#3d5634"),size)
		map.free()
	var texture := ImageTexture.create_from_image(atlas)
	for path in ["res://assets/enironment/gfx/Overworld.png","res://assets/enironment/gfx/objects.png","res://assets/enironment/tree.png","res://resources/world/gfx_terrain.tres","res://resources/world/gfx_water.tres","res://resources/world/gfx_trees.tres","res://resources/world/gfx_boulders.tres"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	texture.set_meta("source_hashes",source_hashes)
	texture.set_meta("boss_locations",boss_locations)
	var error := ResourceSaver.save(texture,"res://resources/maps/world_terrain.res",ResourceSaver.FLAG_COMPRESS)
	print("WORLD MAP BAKE: ",Layout.SIZE," cached pixels, save=",error)
	quit(0 if error == OK else 1)
