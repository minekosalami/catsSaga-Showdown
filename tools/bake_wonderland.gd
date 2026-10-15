extends SceneTree
const Plan = preload("res://scripts/wonderland/layout.gd")
const Builder = preload("res://scripts/wonderland/builder.gd")
const Ornament = preload("res://scripts/wonderland/ornament.gd")
var atlases: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func paint_ellipse(image: Image,point: Vector2,radius: Vector2,color: Color) -> void:
	for y in range(maxi(0,int(point.y-radius.y)),mini(image.get_height()-1,int(point.y+radius.y))+1):
		for x in range(maxi(0,int(point.x-radius.x)),mini(image.get_width()-1,int(point.x+radius.x))+1):
			if ((Vector2(x,y)-point)/radius).length_squared()<1: image.set_pixel(x,y,color)
func cartography(id: String,map: Node2D) -> void:
	var group: String = Plan.group(id)
	if not atlases.has(group):
		var size := Plan.extent(id)
		var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		atlases[group] = image
	var image: Image = atlases[group]
	var region: Dictionary = Plan.regions()[id]
	var road: TileMapLayer = map.get_node_or_null("GardenPaths")
	var floor: TileMapLayer = map.get_node("Ground")
	for y in region.size.y:
		for x in region.size.x:
			var color := Color("#bad5a2") if Plan.OUTDOORS.has(id) else Color("#d3b295")
			if Plan.CASTLE_ROOMS.has(id): color = Color("#ead5d8")
			if floor.get_cell_source_id(Vector2i(x/2,y/2))<0: color = Color("#554968")
			if road != null and road.get_cell_source_id(Vector2i(x/2,y/2))>=0: color = Color("#dfc694")
			image.set_pixelv(region.offset+Vector2i(x,y),color)
	for prop in map.get_children():
		if not prop.has_meta("map_color"): continue
		var point: Vector2 = Vector2(region.offset)+prop.position/16
		var radius := Vector2(3.5,2)
		if prop is Ornament:
			if prop.kind in ["flowers","roses","rug","banner"]: continue
			if prop.kind == "great_tree": radius = Vector2(12,9)
			if prop.kind == "castle": radius = Vector2(24,18)
		paint_ellipse(image,point-Vector2(0,radius.y*.7),radius,prop.get_meta("map_color"))
func run() -> void:
	var maps_only := OS.get_cmdline_user_args().has("--maps-only")
	if FileAccess.file_exists("res://scenes/wonderland/wonderland_forest.tscn") and not OS.get_cmdline_user_args().has("--rebuild") and not maps_only:
		push_error("Wonderland already exists. Edit its scenes directly, or explicitly use -- --rebuild to replace authored maps.")
		quit(1)
		return
	var builder := Builder.new()
	if not maps_only: builder.setup_tiles()
	for id in Plan.regions():
		var map: Node2D = load("res://scenes/wonderland/"+id+".tscn").instantiate() if maps_only else builder.build(id)
		var packed := PackedScene.new()
		var err := OK
		if not maps_only:
			err = packed.pack(map)
			if err == OK: err = ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn")
		if err != OK:
			push_error("Wonderland scene could not be baked: "+id)
			quit(1)
			return
		cartography(id,map)
		print("BAKED ",id," ",map.map_size," nodes=",map.get_child_count())
		map.free()
	for group in atlases:
		var texture := ImageTexture.create_from_image(atlases[group])
		var err := ResourceSaver.save(texture,"res://resources/maps/"+group+"_terrain.res",ResourceSaver.FLAG_COMPRESS)
		if err != OK: quit(1); return
	quit()
