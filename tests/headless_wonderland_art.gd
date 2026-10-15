extends SceneTree
const Plan=preload("res://scripts/wonderland/layout.gd")
func _initialize(): call_deferred("run")
func collect(node: Node,base: Node,result: Dictionary):
 var p=String(base.get_path_to(node))
 if node is CollisionShape2D:
  var s=node.shape
  result[p]={"position":str(node.transform),"parents":str(node.get_parent().transform),"shape":s.get_class(),"size":str(s.size) if s is RectangleShape2D else str(s.radius) if s is CircleShape2D else str(s.get("points"))}
 if node is Marker2D: result[p]={"position":str(node.position),"facing":str(node.get_meta("facing_direction",Vector2.ZERO))}
 if node is Area2D and node.get("destination")!=null:result[p]={"position":str(node.position),"destination":node.destination,"entry":node.entry,"gate":node.get("gate_flag")}
 for c in node.get_children(): collect(c,base,result)
func run():
 var expected=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/wonderland-structure-c5e8815.json"))
 var checks=0
 var failures=0
 for id in Plan.regions():
  var n=load("res://scenes/wonderland/"+id+".tscn").instantiate()
  var data={"map_size":str(n.map_size),"nodes":{}}
  collect(n,n,data.nodes)
  for layer in n.get_children():
   if layer is TileMapLayer:data[layer.name]=str(layer.get_used_cells())
  checks+=1
  if JSON.stringify(data,"",true).sha256_text()!=expected[id]:failures+=1;push_error("Structure changed: "+id)
  n.free()
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/wonderland_human/provenance.json"))
 for path in manifest.files:
  checks+=1
  if FileAccess.get_sha256("res://assets/wonderland_human/"+path)!=manifest.files[path].sha256:failures+=1;push_error("Human source was modified: "+path)
 for path in ["ornament.gd","ambience.gd","builder.gd","asset_catalog.gd","flooded_entrance.gd","reward_chest.gd"]:
  var source=FileAccess.get_file_as_string("res://scripts/wonderland/"+path)
  for forbidden in ["draw_rect(","draw_line(","draw_arc(","draw_polygon(","draw_colored_polygon(","Image.create(","set_pixel(","/The Fan-tasy", "mushroom_houses.png"]:
   checks+=1
   if source.contains(forbidden):failures+=1;push_error("Unsupported art source/shape in "+path+": "+forbidden)
 for name in ["grass","road","wood","marble"]:
  var source=FileAccess.get_file_as_string("res://resources/wonderland/"+name+".tres")
  checks+=1
  if source.contains('type="Image"') or not source.contains("assets/wonderland_human/"):failures+=1;push_error("Floor art is not the licensed source: "+name)
 print("WONDERLAND ART: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
