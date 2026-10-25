extends SceneTree
## One-time, bounded edit of the current scenes. Never rebuilds the world.
const Plan=preload("res://scripts/journey/layout.gd")
const Routes=preload("res://scripts/journey/chapter_routes.gd")
const Art=preload("res://scripts/journey/forest_art.gd")
const REVISION="forest_chapter_polish_v1"
var report: Dictionary={}
var plants: TileSet
func _initialize() -> void:run.call_deferred()
func cells(layer: TileMapLayer) -> Dictionary:
	var result: Dictionary={}
	for cell in layer.get_used_cells():result[cell]=true
	return result
func distance_to(points: PackedVector2Array, point: Vector2) -> float:
	var result:=INF
	for i in range(1,points.size()):result=minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i-1],points[i])))
	return result
func run() -> void:
	if not "--apply" in OS.get_cmdline_user_args():push_error("Pass -- --apply to polish existing baked maps.");quit(1);return
	plants=load("res://resources/journey/plants.tres").duplicate(true)
	for source_id in plants.get_source_count():
		var source: TileSetAtlasSource=plants.get_source(plants.get_source_id(source_id))
		for tile_id in source.get_tiles_count():
			var tile:=source.get_tile_id(tile_id)
			for alternative in range(1,5):
				source.create_alternative_tile(tile,alternative)
				source.get_tile_data(tile,alternative).texture_origin=[Vector2i(-7,-3),Vector2i(6,5),Vector2i(-4,7),Vector2i(5,-6)][alternative-1]
	var plant_path:="res://resources/journey/chapter_plants.tres"
	ResourceSaver.save(plants,plant_path);plants.take_over_path(plant_path)
	for area in Plan.ORDER:polish(area)
	print("FOREST POLISH ",JSON.stringify(report))
	quit()
func polish(area: String) -> void:
	var map=load(Plan.scene(area)).instantiate()
	if map.has_meta(REVISION):map.free();return
	var paths: TileMapLayer=map.get_node("Paths")
	var old:=cells(paths)
	var water:=cells(map.get_node("Water"))
	var bridges:=cells(map.get_node("Bridges"))
	var route:=Routes.curve(area)
	var main: Dictionary={}
	for point in route:
		var radius:=70.0+6*sin(point.x*.003)
		for y in range(int((point.y-radius)/32),int((point.y+radius)/32)+1):
			for x in range(int((point.x-radius)/32),int((point.x+radius)/32)+1):
				var cell:=Vector2i(x,y);var center:=Vector2(cell*32)+Vector2.ONE*16
				if not Rect2(Vector2.ZERO,map.map_size).has_point(center):continue
				if water.has(cell) and not bridges.has(cell):continue
				if center.distance_to(point)<radius:main[cell]=true
	# Secondary trails lose one edge tile, becoming distinct from the broad main
	# route. This changes paint only, never blocks an existing walkable corridor.
	var paths_new: Dictionary={}
	for cell: Vector2i in old:
		var interior:=true
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not old.has(cell+d):interior=false
		if interior or bridges.has(cell):paths_new[cell]=true
	paths_new.merge(main)
	# The existing southern bridge used to terminate in unmarked grass. Small
	# dry-bank approaches now connect its two ends to the retained scenic loop.
	if area=="flooded_forest":
		for approach in Routes.BRIDGE_APPROACHES:
			for point in Routes.smooth(approach):
				for y in range(int((point.y-40)/32),int((point.y+40)/32)+1):
					for x in range(int((point.x-40)/32),int((point.x+40)/32)+1):
						var cell:=Vector2i(x,y)
						if water.has(cell) and not bridges.has(cell):continue
						if (Vector2(cell*32)+Vector2.ONE*16).distance_to(point)<40:paths_new[cell]=true
	paths.clear()
	for cell in paths_new:paths.set_cell(cell,0,Vector2i(1,3))
	Art.paint(map.get_node("TrailSurface"),paths_new)
	var removed:=0
	for node in map.get_children():
		if not node.is_in_group("journey_trees") and not node.is_in_group("journey_props"):continue
		# Clear only the new travel corridor. NPCs/landmarks are never candidates.
		if distance_to(route,node.position)<112 and not water.has(Vector2i(node.position/32)):
			map.remove_child(node);node.free();removed+=1
	var ground: TileMapLayer=map.get_node("GrassGround")
	var understory: TileMapLayer=map.get_node("Understory")
	understory.tile_set=plants
	var noise:=FastNoiseLite.new();noise.seed=91573+Plan.ORDER.find(area)*101;noise.frequency=.015
	var flowers:=0
	# Region-specific groupings replace the previous uniform mix, using intact
	# source cells only. All flora remains non-solid; source PNGs are unchanged.
	understory.clear()
	for cell in ground.get_used_cells():
		var point:=Vector2(cell*32)+Vector2.ONE*16
		var h:=posmod(hash(str(cell)+area),1000)
		var patch:=noise.get_noise_2d(point.x,point.y)
		ground.set_cell(cell,0,Vector2i(h%3,5) if patch>.08 and h%5==0 else Vector2i(1,3))
		if paths_new.has(cell):continue
		if water.has(cell):
			if bridges.has(cell):continue
			var bank:=not water.has(cell+Vector2i.UP) or not water.has(cell+Vector2i.LEFT) or not water.has(cell+Vector2i.RIGHT)
			if bank and h%4==0:understory.set_cell(cell,0,Vector2i(8+h%3,1))
			elif not bank and h%31==0:understory.set_cell(cell,0,Vector2i(12+h%2,2))
			continue
		var garden:=false
		for center in Routes.GARDENS[area]:
			if point.distance_to(center)<100+patch*80:garden=true;break
		var edge:=false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if paths_new.has(cell+offset):edge=true
		# Leave deliberate quiet spaces; avoid filling every path edge with props.
		if not ((garden and h%3!=0) or (edge and patch>-.03 and h%4==0) or (patch>.18 and h%9==0)):continue
		if area=="deep_forest":
			if h%3==0:understory.set_cell(cell,2,Vector2i(h%3,3))
			else:understory.set_cell(cell,0,Vector2i(2+h%4,0))
		elif area=="bart_area":
			understory.set_cell(cell,1,Vector2i([0,3,4,8][h%4],1 if h%5==0 else 2))
		elif area=="flooded_forest":
			understory.set_cell(cell,0,Vector2i(6+h%2,h%2))
		else:
			understory.set_cell(cell,1,Vector2i([0,5,6][h%3],2))
		if understory.get_cell_source_id(cell)>=0:
			understory.set_cell(cell,understory.get_cell_source_id(cell),understory.get_cell_atlas_coords(cell),1+h%4)
		flowers+=1
	map.set_meta(REVISION,true)
	map.set_meta("main_route",Routes.MAIN[area])
	map.set_meta("tree_count",map.get_children().filter(func(n):return n.is_in_group("journey_trees")).size())
	var packed:=PackedScene.new()
	var error:=packed.pack(map)
	if error==OK:error=ResourceSaver.save(packed,Plan.scene(area))
	report[area]={"cleared_decorations":removed,"main_tiles":main.size(),"trail_tiles":paths_new.size(),"planted_cells":flowers,"trees":map.get_meta("tree_count")}
	map.free()
	if error!=OK:push_error("Failed saving "+area);quit(1)
