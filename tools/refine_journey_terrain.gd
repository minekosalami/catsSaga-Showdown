extends SceneTree
## Authoring pass on the existing maps: preserve geography and node identities.
## This paints licensed atlas tiles; it does not draw or generate artwork.
const Plan = preload("res://scripts/journey/layout.gd")
const Terrain = preload("res://scripts/journey/terrain_rules.gd")
const Art = preload("res://scripts/journey/forest_art.gd")
const CELL := 32.0
var save_locations: Dictionary={}
var map: Node2D
var paths := {}
var waters := {}
var route_samples := PackedVector2Array()
var safe_samples := PackedVector2Array()
var reserves := PackedVector2Array()
var id := ""
var grid := Vector2i.ZERO

func _initialize() -> void: run.call_deferred()

func stamp(point: Vector2,radius: float,into: Dictionary) -> void:
	for y in range(maxi(0,floori((point.y-radius)/CELL)),mini(grid.y,ceili((point.y+radius)/CELL))):
		for x in range(maxi(0,floori((point.x-radius)/CELL)),mini(grid.x,ceili((point.x+radius)/CELL))):
			var cell := Vector2i(x,y)
			if (Vector2(cell)*CELL+Vector2.ONE*16).distance_to(point)<radius:into[cell]=true

func curve_route(points: PackedVector2Array,radius := 68.0) -> void:
	var curve := Curve2D.new()
	curve.bake_interval=10
	for i in points.size():
		var tangent := Vector2.ZERO
		if i>0 and i<points.size()-1:
			var before := points[i]-points[i-1]
			var after := points[i+1]-points[i]
			tangent=(before.normalized()+after.normalized()).normalized()*minf(before.length(),after.length())*.30
		curve.add_point(points[i],-tangent,tangent)
	var samples := curve.get_baked_points()
	for i in samples.size():
		# Small gradual shoulder changes, rather than a repeated rectangular road.
		stamp(samples[i],radius+sin(i*.14)*3+sin(i*.047)*4,paths)
		route_samples.append(samples[i])
		safe_samples.append(samples[i])

func closest_sample(point: Vector2) -> Vector2:
	var nearest := route_samples[0]
	var distance := INF
	for sample in route_samples:
		var candidate := sample.distance_squared_to(point)
		if candidate<distance:distance=candidate;nearest=sample
	return nearest

func protected_distance(point: Vector2) -> float:
	var nearest := INF
	for reserve in reserves:nearest=minf(nearest,reserve.distance_to(point))
	return nearest

func route_distance(point: Vector2) -> float:
	var nearest := INF
	for sample in safe_samples:nearest=minf(nearest,sample.distance_to(point))
	return nearest

func author_routes() -> void:
	curve_route(Plan.points(id),64)
	var width: float=map.map_size.x
	for index in 3:
		var x: float=width*(.25+index*.24)
		var extent: float=map.map_size.y*(.76 if index%2==0 else .24)
		var branch := PackedVector2Array([Vector2(x-180,Plan.SEAM_Y),Vector2(x-160,extent-80),Vector2(x+80,extent),Vector2(x+320,extent-180),Vector2(x+360,Plan.SEAM_Y)])
		if id=="flooded_forest":
			branch=[PackedVector2Array([Vector2(844,912),Vector2(900,1500),Vector2(850,2200),Vector2(1104,2334),Vector2(1344,2154),Vector2(1500,1800),Vector2(1400,1200),Vector2(1376,1130)]),PackedVector2Array([Vector2(2144,816),Vector2(2087,737),Vector2(2200,440),Vector2(2680,600),Vector2(2440,1100)]),PackedVector2Array([Vector2(2850,912),Vector2(2580,1560),Vector2(2570,2080),Vector2(2810,2400),Vector2(3070,2334),Vector2(3552,2380),Vector2(3680,1990),Vector2(3552,1550),Vector2(3200,1300),Vector2(2850,912)])][index]
		curve_route(branch,51)
	# Use the existing landmark/interaction coordinates as the source of truth.
	for marker in map.get_node("Discoveries").get_children():
		reserves.append(marker.position)
		var near:=closest_sample(marker.position)
		if near.distance_to(marker.position)>36:curve_route(PackedVector2Array([near,near.lerp(marker.position,.5)+Vector2(24,-20),marker.position]),48)
	for npc in map.get_node("Characters").get_children():
		reserves.append(npc.position)
		var approach: Vector2=npc.position+Vector2(0,64)
		var near:=closest_sample(approach)
		curve_route(PackedVector2Array([near,near.lerp(approach,.5),approach]),55)
	for point: Vector2 in save_locations.get(id,[]):
		reserves.append(point)
		var near:=closest_sample(point)
		if near.distance_to(point)>110:curve_route(PackedVector2Array([near,near.lerp(point,.5)+Vector2(16,-12),point]),45)
		# A star's final approach is grass. Retain its clear access corridor.
		for y in range(floori((point.y-86)/CELL),ceili((point.y+86)/CELL)):
			for x in range(floori((point.x-86)/CELL),ceili((point.x+86)/CELL)):
				var cell:=Vector2i(x,y)
				if (Vector2(cell)*CELL+Vector2.ONE*16).distance_to(point)<86:paths.erase(cell)

func flooded(point: Vector2) -> bool:
	# Connected central river and its broad lowland basins. Main crossings stay
	# at the two existing bridge coordinates; dry routes become raised banks.
	var center:=1950.0+sin(point.y*.004)*105.0
	var river:=absf(point.x-center)<174.0+sin(point.y*.0021)*24
	var west:=((point-Vector2(1110,2200))/Vector2(890,650)).length()<1
	var east:=((point-Vector2(3110,2030))/Vector2(790,650)).length()<1
	var north:=((point-Vector2(2690,400))/Vector2(740,360)).length()<1
	var west_link:=point.x>1140 and point.x<2040 and absf(point.y-(2150+sin(point.x*.005)*80))<140
	var east_link:=point.x>1950 and point.x<3140 and absf(point.y-(1880+sin(point.x*.004)*95))<155
	return river or west or east or north or west_link or east_link

func rebuild_water(old: TileMapLayer,bridges: TileMapLayer) -> void:
	if id!="flooded_forest":
		for cell in old.get_used_cells():waters[cell]=true
		return
	for y in grid.y:
		for x in grid.x:
			var cell:=Vector2i(x,y)
			var point:=Vector2(cell)*CELL+Vector2.ONE*16
			if not flooded(point):continue
			var river:=absf(point.x-(1950.0+sin(point.y*.004)*105.0))<174.0+sin(point.y*.0021)*24
			# Keep required destinations dry and generous grass approaches intact.
			if protected_distance(point)<86:continue
			if not river and route_distance(point)<94 and bridges.get_cell_source_id(cell)<0:continue
			waters[cell]=true
	# Save clearings, entries and both banks of each authored deck stay dry.
	for entry in map.get_node("Entries").get_children():
		for cell: Vector2i in waters.keys():
			if (Vector2(cell)*CELL+Vector2.ONE*16).distance_to(entry.position)<110:waters.erase(cell)

func paint_layers() -> void:
	var path: TileMapLayer=map.get_node("Paths")
	var water: TileMapLayer=map.get_node("Water")
	var bridge: TileMapLayer=map.get_node("Bridges")
	var path_surface: TileMapLayer=map.get_node("TrailSurface")
	var water_surface: TileMapLayer=map.get_node("WaterSurface")
	var lpc: bool=map.has_meta("environment_art")
	path.clear();water.clear();path_surface.clear();water_surface.clear()
	for cell: Vector2i in paths:
		# Hidden logical footprint retains the simple center tile; the visible
		# quarter atlas supplies convex and concave terrain transitions.
		if waters.has(cell) and bridge.get_cell_source_id(cell)<0:continue
		path.set_cell(cell,0,Vector2i(1,3) if lpc else Vector2i(12,8))
	var visible_paths: Dictionary={}
	for cell in path.get_used_cells():visible_paths[cell]=true
	for cell: Vector2i in waters:
		water.set_cell(cell,0,Vector2i(1,3) if lpc else Vector2i(12,7),1 if bridge.get_cell_source_id(cell)>=0 else 0)
	if lpc:
		Art.paint(path_surface,visible_paths)
		Art.paint(water_surface,waters,true)
	else:
		Terrain.paint(path_surface,visible_paths,false)
		Terrain.paint(water_surface,waters,true)
	var plants: TileMapLayer=map.get_node("Understory")
	for cell in plants.get_used_cells():
		if waters.has(cell) or paths.has(cell) or protected_distance(Vector2(cell)*CELL+Vector2.ONE*16)<86:plants.erase_cell(cell)

func adjust_conflicting_props() -> int:
	var shifted:=0
	var bodies: Array[Node]=map.find_children("*","StaticBody2D",true,false)
	var occupied: Array[Vector2]=[]
	for body in bodies:
		if body.is_in_group("journey_trees") or body.is_in_group("journey_props"):occupied.append(body.position)
	for body in bodies:
		if not body.is_in_group("journey_trees") and not body.is_in_group("journey_props"):continue
		var origin: Vector2=body.position
		if route_distance(origin)>92 and protected_distance(origin)>106:continue
		occupied.erase(origin)
		var found:=false
		for radius in range(32,385,24):
			for step in 32:
				var angle:=TAU*(float(step)/32)+fposmod(origin.x*.001+origin.y*.003,TAU)
				var candidate:=origin+Vector2.from_angle(angle)*radius
				if not Rect2(Vector2(48,64),map.map_size-Vector2(96,112)).has_point(candidate) or route_distance(candidate)<103 or protected_distance(candidate)<112:continue
				# Waterlogged trees remain at their original positions elsewhere;
				# relocated trunks belong on the closest dry bank.
				if waters.has(Vector2i(candidate/CELL)):continue
				var clear:=true
				for other in occupied:
					if other.distance_to(candidate)<38:clear=false;break
				if not clear:continue
				body.position=candidate;found=true;shifted+=1;break
			if found:break
		occupied.append(body.position)
		if not found:push_warning("No nearby relocation for "+str(body.name))
	return shifted

func refine(area: String,apply: bool) -> void:
	id=area
	map=load(Plan.scene(area)).instantiate()
	grid=Vector2i(map.map_size/CELL)
	paths.clear();waters.clear();route_samples.clear();safe_samples.clear();reserves.clear()
	var water: TileMapLayer=map.get_node("Water")
	var old_count:=water.get_used_cells().size()
	author_routes()
	rebuild_water(water,map.get_node("Bridges"))
	paint_layers()
	var shifted:=adjust_conflicting_props()
	map.set_meta("landscape_refinement",1)
	map.set_meta("water_cell_count",waters.size())
	if not map.has_meta("pre_refinement_water_cells"):map.set_meta("pre_refinement_water_cells",old_count)
	if apply:
		var packed:=PackedScene.new()
		var error:=packed.pack(map)
		if error==OK:error=ResourceSaver.save(packed,Plan.scene(id))
		if error!=OK:push_error("Could not save "+id);quit(1);return
	print("LANDSCAPE ",id," water ",old_count," -> ",waters.size(),"/",grid.x*grid.y," (",snappedf(float(waters.size())/(grid.x*grid.y)*100,.01),"%), paths=",map.get_node("Paths").get_used_cells().size(),", moved props=",shifted,", applied=",apply)
	map.free()

func run() -> void:
	var apply: bool="--apply" in OS.get_cmdline_user_args()
	# The interaction script uses autoloads, so load it after engine bootstrap.
	var save_script: Script=load("res://scripts/world/save_statue.gd")
	save_locations=save_script.get_script_constant_map().LOCATIONS
	for area in Plan.ORDER:refine(area,apply)
	quit()
