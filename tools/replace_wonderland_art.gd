extends SceneTree
## One-time VISUAL migration of existing scenes. Never calls Builder.build().
const Plan = preload("res://scripts/wonderland/layout.gd")
const Art = preload("res://scripts/wonderland/ornament.gd")
var tile_sets := {}
var failures := 0
func _initialize() -> void:call_deferred("run")
func atlas_set(cells: Array[Vector2i],terrain := false) -> TileSet:
 var result := TileSet.new()
 result.tile_size = Vector2i(16,16)
 var atlas := TileSetAtlasSource.new()
 atlas.texture = Art.RPG
 atlas.texture_region_size = Vector2i(16,16)
 atlas.separation = Vector2i.ONE
 for cell in cells:atlas.create_tile(cell)
 result.add_source(atlas,0)
 if terrain:
  result.add_terrain_set()
  result.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
  result.add_terrain(0)
  result.set_terrain_name(0,0,"Garden path")
  result.set_terrain_color(0,0,Color("#b58d5c"))
  for cell in cells:
   var data := atlas.get_tile_data(cell,0)
   data.terrain_set = 0;data.terrain = 0
   for pair in [[TileSet.CELL_NEIGHBOR_TOP_SIDE,cell.y>21],[TileSet.CELL_NEIGHBOR_RIGHT_SIDE,cell.x<9],[TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,cell.y<23],[TileSet.CELL_NEIGHBOR_LEFT_SIDE,cell.x>7]]:
    data.set_terrain_peering_bit(pair[0],0 if pair[1] else -1)
 return result
func new_visual(old: Node2D,kind: String) -> Node2D:
 var art := Art.new()
 art.name = old.name
 art.kind = kind
 art.position = old.position
 art.z_index = old.z_index
 var parent := old.get_parent()
 var index := old.get_index()
 parent.remove_child(old);parent.add_child(art);parent.move_child(art,index)
 art.owner = parent.owner if parent.owner != null else parent
 old.free()
 return art
func visuals(node: Node,map: Node) -> void:
 for child in node.get_children():
  if child is Sprite2D:
   var file: String = child.texture.atlas.resource_path if child.texture is AtlasTexture else child.texture.resource_path
   if file.contains("/wonderland/"):
    var dimensions: Vector2 = child.texture.get_size()
    var offset: float = child.position.x/2
    var kind := "house" if file.contains("House_Hay") else ("tree" if file.contains("Tree_Emerald") else ("bush" if file.contains("Bush_") else "mushroom_house"))
    var art := new_visual(child,kind)
    art.position = Vector2.ZERO
    art.scale = Vector2.ONE*2
    art.footprint = dimensions
    art.visual_offset = Vector2(offset,0)
    art.variant = int(file.get_file().get_basename().right(1))%3
  elif child is Polygon2D:
   if child.color.a<.4:
    node.remove_child(child);child.free()
   else:
    var rect := Rect2(child.polygon[0],Vector2.ZERO)
    for point in child.polygon:rect = rect.expand(point)
    var backdrop: bool = child.z_index < -10
    var art := new_visual(child,"wall_background" if backdrop else "wall")
    art.scale = Vector2.ONE*2
    art.footprint = rect.size/2
    art.visual_offset = rect.position/2
  elif child is Line2D:
   node.remove_child(child);child.free()
  else:visuals(child,map)
func migrate(map: Node2D,id: String) -> void:
 var outside := Plan.OUTDOORS.has(id)
 var floor: TileMapLayer = map.get_node("Ground")
 var cells := floor.get_used_cells()
 floor.tile_set = tile_sets.grass if outside else (tile_sets.marble if Plan.CASTLE_ROOMS.has(id) else tile_sets.wood)
 for cell in cells:floor.set_cell(cell,0,Vector2i(5,(absi(cell.x*7+cell.y*11)%9)/8) if outside else (Vector2i(7,2) if Plan.CASTLE_ROOMS.has(id) else Vector2i(9,2)))
 var roads: TileMapLayer = map.get_node_or_null("GardenPaths")
 if roads != null:
  var occupied := {}
  for cell in roads.get_used_cells():occupied[cell] = true
  roads.tile_set = tile_sets.road
  for cell: Vector2i in occupied:
   var x := 8
   var y := 22
   if not occupied.has(cell+Vector2i.LEFT):x = 7
   elif not occupied.has(cell+Vector2i.RIGHT):x = 9
   if not occupied.has(cell+Vector2i.UP):y = 21
   elif not occupied.has(cell+Vector2i.DOWN):y = 23
   roads.set_cell(cell,0,Vector2i(x,y))
 visuals(map,map)
func run() -> void:
 if not OS.get_cmdline_user_args().has("--apply"):
  push_error("Explicit -- --apply required. This tool changes visuals in existing scenes only.");quit(1);return
 var roads: Array[Vector2i] = []
 for y in range(21,24):
  for x in range(7,10):roads.append(Vector2i(x,y))
 tile_sets = {"grass":atlas_set([Vector2i(5,0),Vector2i(5,1)]),"road":atlas_set(roads,true),"wood":atlas_set([Vector2i(9,2)]),"marble":atlas_set([Vector2i(7,2)])}
 # Instantiate before replacing resources; no gameplay _ready() or world generation.
 var maps := {}
 for id in Plan.regions():maps[id] = load("res://scenes/wonderland/"+id+".tscn").instantiate()
 for kind in tile_sets:
  var path: String = "res://resources/wonderland/"+kind+".tres"
  tile_sets[kind].take_over_path(path)
  if ResourceSaver.save(tile_sets[kind],path)!=OK:failures += 1
 for id in maps:
  var map: Node2D = maps[id]
  migrate(map,id)
  var scene := PackedScene.new()
  if scene.pack(map)!=OK or ResourceSaver.save(scene,"res://scenes/wonderland/"+id+".tscn")!=OK:failures += 1
  print("REPLACED VISUALS ",id)
  map.free()
 quit(1 if failures else 0)
