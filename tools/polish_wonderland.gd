extends SceneTree
## Visual-only authoring pass over baked geography. Never calls Builder.build().
const Plan = preload("res://scripts/wonderland/layout.gd")
const Art = preload("res://scripts/wonderland/ornament.gd")
const FLOOR = preload("res://assets/wonderland_human/ninja/tileset_floor.png")
const LARGE_FLOOR = preload("res://assets/wonderland_human/ninja/Floor.png")
var sets := {}
func _initialize() -> void:call_deferred("run")
func atlas(texture: Texture2D,cell_size: int,cells: Array[Vector2i],solid := false) -> TileSet:
 var result := TileSet.new()
 result.tile_size = Vector2i.ONE*cell_size
 var source := TileSetAtlasSource.new()
 source.texture = texture
 source.texture_region_size = Vector2i.ONE*cell_size
 if solid:
  result.add_physics_layer()
  result.set_physics_layer_collision_layer(0,1)
  result.set_physics_layer_collision_mask(0,2)
 result.add_source(source,0)
 for cell in cells:
  source.create_tile(cell)
  if solid:
   var data := source.get_tile_data(cell,0)
   data.set_collision_polygons_count(0,1)
   var half := cell_size*.5
   data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-half,-half),Vector2(half,-half),Vector2(half,half),Vector2(-half,half)]))
 return result
func paint_layer(map: Node2D,name: String,set_name: String,z: int) -> TileMapLayer:
 var layer := TileMapLayer.new()
 layer.name = name
 layer.tile_set = sets[set_name]
 layer.scale = Vector2.ONE*.5
 layer.z_index = z
 layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 map.add_child(layer)
 layer.owner = map
 return layer
func decoration(map: Node2D,kind: String,point: Vector2,variant: int,color := Color.WHITE) -> void:
 var art := Art.new()
 art.name = "Fairytale"+kind.to_pascal_case()+str(map.get_child_count())
 art.kind = kind
 art.position = point
 art.scale = Vector2.ONE*2
 art.variant = variant
 art.accent = color
 map.add_child(art)
 art.owner = map
func river_y(x: int) -> int:
 # One continuous river across the three southern regions, including map seams.
 return roundi(9+sin(x*.073)+sin(x*.027)*.75)
func river(map: Node2D,id: String,roads: TileMapLayer) -> void:
 if id not in ["tea_gardens","wonderland_forest","mushroom_thicket"]:return
 var offset: int = Plan.OUTDOORS[id].offset.x/2
 var water := paint_layer(map,"FairytaleWater","water",-7)
 var bridge := paint_layer(map,"FairytaleBridges","bridge",-4)
 bridge.modulate = Color("#b7c6dc")
 var occupied := {}
 for x in range(int(map.map_size.x/32)):
  var y := river_y(x+offset)
  for dy in range(-2,3): occupied[Vector2i(x,y+dy)] = true
 var bridge_cells := {}
 if id != "wonderland_forest":
  var top := 10000
  var bottom := 0
  for x in range(38,43):
   top = mini(top,river_y(x+offset)-2)
   bottom = maxi(bottom,river_y(x+offset)+2)
  for x in range(38,43):
   for y in range(top,bottom+1):bridge_cells[Vector2i(x,y)] = true
  for cell: Vector2i in bridge_cells:bridge.set_cell(cell,0,Vector2i(1,14))
  for side in [38*32-4,43*32+4]:
   for y in range(top,bottom+1):
    decoration(map,"bridge_rail",Vector2(side,y*32+16),0)
    map.get_child(map.get_child_count()-1).rotation = PI*.5
 for cell: Vector2i in occupied:
  var tx := 12
  var ty := 7
  if not occupied.has(cell+Vector2i.LEFT):tx = 11
  elif not occupied.has(cell+Vector2i.RIGHT):tx = 13
  if not occupied.has(cell+Vector2i.UP):ty = 6
  elif not occupied.has(cell+Vector2i.DOWN):ty = 8
  if not bridge_cells.has(cell):water.set_cell(cell,0,Vector2i(tx,ty))
 # Existing trees retain their bodies; hide only canopies whose roots are underwater.
 for node in map.find_children("*","Node2D",true,false):
  if node.get_script() == Art and node.kind in ["tree","bush","flowers","leaf_litter"]:
   var cell := Vector2i(map.to_local(node.global_position)/32)
   node.visible = water.get_cell_source_id(cell)<0 and (bridge.get_cell_source_id(cell)<0 or node.kind == "tree")
func run() -> void:
 if not OS.get_cmdline_user_args().has("--apply"):push_error("Use -- --apply");quit(1);return
 var grass: Array[Vector2i] = []
 for x in range(11,16):grass.append(Vector2i(x,12))
 var roads: Array[Vector2i] = []
 var water: Array[Vector2i] = []
 for y in range(7,10):
  for x in range(11,14):roads.append(Vector2i(x,y));water.append(Vector2i(x,y-1))
 sets = {"grass":atlas(FLOOR,16,grass),"road":atlas(FLOOR,16,roads),"wood":atlas(LARGE_FLOOR,64,[Vector2i(1,14)]),"marble":atlas(preload("res://assets/wonderland_human/ninja/tileset_interior_floor.png"),16,[Vector2i(1,1),Vector2i(9,1)]),"water":atlas(LARGE_FLOOR,64,water,true),"bridge":atlas(LARGE_FLOOR,64,[Vector2i(1,14)])}
 sets.road.add_terrain_set()
 sets.road.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
 sets.road.add_terrain(0)
 sets.road.set_terrain_name(0,0,"Woodland path")
 var road_source := sets.road.get_source(0) as TileSetAtlasSource
 for cell in roads:
  var data := road_source.get_tile_data(cell,0)
  data.terrain_set = 0
  data.terrain = 0
  for pair in [[TileSet.CELL_NEIGHBOR_TOP_SIDE,cell.y>7],[TileSet.CELL_NEIGHBOR_RIGHT_SIDE,cell.x<13],[TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,cell.y<9],[TileSet.CELL_NEIGHBOR_LEFT_SIDE,cell.x>11]]:
   data.set_terrain_peering_bit(pair[0],0 if pair[1] else -1)
 var maps := {}
 for id in Plan.regions():maps[id] = load("res://scenes/wonderland/"+id+".tscn").instantiate()
 for kind in sets:
  sets[kind].take_over_path("res://resources/wonderland/"+kind+".tres")
  ResourceSaver.save(sets[kind],sets[kind].resource_path)
 for id in maps:
  var map: Node2D = maps[id]
  for old in map.get_children():
   if String(old.name).begins_with("Fairytale"):old.free()
  var ground: TileMapLayer = map.get_node("Ground")
  var cells := ground.get_used_cells()
  var outdoor := Plan.OUTDOORS.has(id)
  ground.tile_set = sets.grass if outdoor else (sets.marble if Plan.CASTLE_ROOMS.has(id) else sets.wood)
  if not outdoor and not Plan.CASTLE_ROOMS.has(id):ground.scale = Vector2.ONE*.5
  if not outdoor and not Plan.CASTLE_ROOMS.has(id):ground.modulate = Color("#bdc8d4")
  for cell in cells:
   var detail := absi(cell.x*721+cell.y*137)%97
   ground.set_cell(cell,0,Vector2i(11+detail%5,12) if outdoor and detail<20 else (Vector2i(11,12) if outdoor else (Vector2i(1,1) if Plan.CASTLE_ROOMS.has(id) else Vector2i(1,14))))
  for art in map.find_children("*","Node2D",true,false):
   if art.get_script() == Art and art.kind in ["house","mushroom_house","teapot_house","clock_house","pink_house"]:
    for building in Plan.BUILDINGS:
     if art.global_position.distance_to(building.point)<1:art.accent = building.color
  var roads_layer: TileMapLayer = map.get_node_or_null("GardenPaths")
  if roads_layer != null:
   var used := {}
   for cell in roads_layer.get_used_cells():used[cell] = true
   roads_layer.tile_set = sets.road
   for cell: Vector2i in used:
    var x := 12
    var y := 8
    if not used.has(cell+Vector2i.LEFT):x = 11
    elif not used.has(cell+Vector2i.RIGHT):x = 13
    if not used.has(cell+Vector2i.UP):y = 7
    elif not used.has(cell+Vector2i.DOWN):y = 9
    roads_layer.set_cell(cell,0,Vector2i(x,y))
   river(map,id,roads_layer)
   var rng := RandomNumberGenerator.new()
   rng.seed = hash(id+"fairytale")
   for i in (230 if id != "queens_castle" else 80):
    var point := Vector2(rng.randf_range(80,map.map_size.x-80),rng.randf_range(100,map.map_size.y-100))
    var cell := Vector2i(point/32)
    if roads_layer.get_cell_source_id(cell)>=0:continue
    var water_layer := map.get_node_or_null("FairytaleWater") as TileMapLayer
    if water_layer != null and water_layer.get_cell_source_id(cell)>=0:continue
    var bridge_layer := map.get_node_or_null("FairytaleBridges") as TileMapLayer
    if bridge_layer != null and bridge_layer.get_cell_source_id(cell)>=0:continue
    decoration(map,"grass_tuft" if i%4 else "flowers",point,i,Color("#eea3d8") if i%3 else Color("#ffe8a3"))
   # Paired lamps give route edges and town approaches a deliberate rhythm.
   for portal in map.get_node("Portals").get_children():
    for side in [-1,1]:
     var point: Vector2 = portal.position.clamp(Vector2(140,150),map.map_size-Vector2(140,150))+Vector2(side*94,0)
     decoration(map,"lantern",point,0)
  for node in map.find_children("*","Node2D",true,false):
   if node.get_script() == Art and node.kind in ["house","teapot_house","clock_house","pink_house","mushroom_house"]:
    # Flower boxes and door lamps use existing placement, not a replacement building.
    decoration(map,"lantern",node.position+Vector2(-65,15),0)
  var packed := PackedScene.new()
  packed.pack(map)
  ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn")
  print("POLISHED ",id)
  map.free()
 quit()
