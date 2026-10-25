extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
var checks:=0
var failures:=0
var manifest:Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func signature(scene:PackedScene) -> Dictionary:
 var state:=scene.get_state();var result:Dictionary={}
 for i in state.get_node_count():
  var path:=str(state.get_node_path(i))
  if not (path.begins_with("Entries/") or path.begins_with("Portals/") or path=="CastleGate"):continue
  var properties:Dictionary={}
  for j in state.get_node_property_count(i):
   var name:=str(state.get_node_property_name(i,j))
   if name in ["position","destination","entry","required_flag","requires_castle","kind"]:properties[name]=var_to_str(state.get_node_property_value(i,j))
  if not properties.is_empty():result[path]=properties
 return result
func clear(map:Node2D,point:Vector2,probe:PhysicsShapeQueryParameters2D) -> bool:
 probe.transform=Transform2D(0,point)
 return map.is_walkable_position(point) and map.get_world_2d().direct_space_state.intersect_shape(probe,1).is_empty()
func run() -> void:
 var session:=root.get_node("Session")
 session.story_flags["wonderland_arrived"]=true;session.story_flags["wonderland_intro_completed"]=true
 var shape:=RectangleShape2D.new();shape.size=Vector2(28,28)
 var probe:=PhysicsShapeQueryParameters2D.new();probe.shape=shape;probe.collision_mask=1
 var fixture="res://tests/fixtures/wonderland_connections.json"
 if FileAccess.file_exists(fixture):manifest=JSON.parse_string(FileAccess.get_file_as_string(fixture))
 for id in Layout.regions():
  var scene:PackedScene=load("res://scenes/wonderland/"+id+".tscn")
  if OS.get_cmdline_user_args().has("--record-baseline"):
   var old:PackedScene=load("/workspace/.catsSaga-validation/wonderland-rebuild/before/extracted/scenes/wonderland/"+id+".tscn")
   manifest[id]=signature(old)
  check(signature(scene)==manifest.get(id,{}),id+" unchanged functional positions and connections")
  var viewport:=SubViewport.new();viewport.world_2d=World2D.new();root.add_child(viewport)
  var map:=scene.instantiate();viewport.add_child(map)
  await physics_frame;await physics_frame;await physics_frame
  check(map.map_size==Vector2(Layout.regions()[id].size)*16,id+" unchanged extent")
  var gate:=map.get_node_or_null("CastleGate")
  if gate!=null:
   check(not gate.open_now(),"Castle remains locked")
   session.story_flags[Layout.CASTLE_OPEN]=true
   # Gate observes flags in _process, then defers its physics-shape change.
   await process_frame;await process_frame;await physics_frame;await physics_frame
   check(gate.barrier.disabled,"Unlocked gate has applied its deferred collider change")
  var astar:=AStarGrid2D.new();astar.region=Rect2i(Vector2i.ZERO,Vector2i(map.map_size/32));astar.cell_size=Vector2(32,32);astar.offset=Vector2(16,16);astar.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;astar.update()
  for y in astar.region.size.y:
   for x in astar.region.size.x:
    if not clear(map,Vector2(x*32+16,y*32+16),probe):astar.set_point_solid(Vector2i(x,y),true)
  var start:Vector2=map.get_node("Entries").get_child(0).position
  var start_cell:=Vector2i(start/32)
  check(clear(map,start,probe),id+" first spawn unobstructed")
  for entry in map.get_node("Entries").get_children():
   check(clear(map,entry.position,probe),id+" spawn "+entry.name+" unobstructed")
   var to:=Vector2i(entry.position/32)
   check(not astar.get_point_path(start_cell,to).is_empty(),id+" route to "+entry.name)
  for portal in map.get_node("Portals").get_children():
   if portal.destination=="flooded_forest":continue # Established one-way story entrance.
   var to:=Vector2i(portal.position/32).clamp(Vector2i.ZERO,astar.region.size-Vector2i.ONE)
   check(not astar.get_point_path(start_cell,to).is_empty(),id+" reachable door "+portal.name+" at "+str(to))
  check(map.find_children("*","CharacterBody2D",true,false).is_empty(),id+" contains no new characters/enemies")
  print("CHECKED ",id)
  viewport.queue_free();await process_frame
  session.story_flags.erase(Layout.CASTLE_OPEN)
 if OS.get_cmdline_user_args().has("--record-baseline"):
  var file:=FileAccess.open(fixture,FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"))
 print("WONDERLAND ENVIRONMENT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
