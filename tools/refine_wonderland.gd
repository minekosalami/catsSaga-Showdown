extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
const Terrain=preload("res://scripts/wonderland/terrain.gd")
const Builder=preload("res://scripts/wonderland/builder.gd")
const Prop=preload("res://scripts/wonderland/environment_prop.gd")
const Ornament=preload("res://scripts/wonderland/ornament.gd")
var map:Node2D
var builder:RefCounted
func _initialize():run.call_deferred()
func outdoor(id:String) -> void:
 var paths:TileMapLayer=map.get_node("GardenPaths");var water:TileMapLayer=map.get_node("FairytaleWater")
 var roads:=Terrain.occupied(paths);var ponds:=Terrain.occupied(water)
 var links:Array[Dictionary]=[]
 var targets:Array[String]=[]
 for link in Layout.LINKS:
  if id not in [link[0],link[3]]:continue
  var a:=0 if id==link[0] else 3;var b:=3-a
  targets.append(link[b]);links.append({"side":link[a+1],"along":link[a+2]})
  var portal=map.get_node_or_null("Portals/To_"+link[b])
  if portal==null:builder.portal("To_"+link[b],Layout.edge(id,link[a+1],link[a+2]),link[b],"From_"+id,link[a+1])
  var entry=map.get_node_or_null("Entries/From_"+link[b])
  if entry==null:builder.entry("From_"+link[b],Layout.edge(id,link[a+1],link[a+2],192),Layout.inward(link[a+1]))
  Terrain.paint_route(roads,PackedVector2Array([Layout.edge(id,link[a+1],link[a+2],0),Layout.edge(id,link[a+1],link[a+2],224)]),76,map.map_size)
 for portal in map.get_node("Portals").get_children():
  if not Layout.OUTDOORS.has(portal.destination) or portal.destination in targets:continue
  var p:Vector2=portal.position
  # Retired seam becomes a wooded trail end. Old entry markers remain load-compatible.
  for cell:Vector2i in roads.keys():
   var point:=Vector2(cell*32)+Vector2(16,16)
   if (p.x<64 and point.x<128 and absf(point.y-p.y)<200) or (p.x>map.map_size.x-64 and point.x>map.map_size.x-128 and absf(point.y-p.y)<200) or (p.y<64 and point.y<128 and absf(point.x-p.x)<200) or (p.y>map.map_size.y-64 and point.y>map.map_size.y-128 and absf(point.x-p.x)<200):roads.erase(cell)
  if not map.has_meta("serpentine_route"):
   for delta in [-72,8,80]:
    var tree=Prop.new();tree.kind="tree";tree.variant=2;tree.scale=Vector2.ONE*2
    tree.position=p+Vector2(40,delta) if p.x<64 else (p+Vector2(-40,delta) if p.x>map.map_size.x-64 else (p+Vector2(delta,48) if p.y<64 else p+Vector2(delta,-32)))
    tree.name="ClosedTrail"+str(map.get_child_count());map.add_child(tree);builder.solid(tree,Vector2(16,12),Vector2(0,-4))
  portal.free()
 # Local new connections; all established interior routes/landmarks remain.
 var additions:Dictionary={
 "mushroom_thicket":[Vector2(2220,990),Vector2(2400,1000),Vector2(2560,1000)],
 "queens_castle":[Vector2(0,1000),Vector2(200,1000),Vector2(360,920),Vector2(650,900),Vector2(830,1040),Vector2(1000,1230)]}
 var added:=PackedVector2Array()
 if additions.has(id):
  added=preload("res://scripts/wonderland/environment_plan.gd").smooth(additions[id]);Terrain.paint_route(roads,added,76,map.map_size)
 # A ground cell cannot simultaneously be path and pond (including shore fringe).
 for cell:Vector2i in ponds.keys():
  var conflict:=false
  for dy in range(-1,2):
   for dx in range(-1,2):
    if roads.has(cell+Vector2i(dx,dy)):conflict=true
  if conflict:ponds.erase(cell)
 Terrain.repaint(paths,roads);Terrain.repaint(water,ponds,true)
 # Remove foliage only from the two new walking corridors, retaining dense groves elsewhere.
 if not added.is_empty():
  for art in map.get_children():
   if art.get_script()!=Prop or art.kind not in ["tree","mushroom","fence"]:continue
   var near:=false
   for i in range(1,added.size()):
    if art.position.distance_to(Geometry2D.get_closest_point_to_segment(art.position,added[i-1],added[i]))<130:near=true
   if near:art.free()
 var border:TileMapLayer=map.get_node("LivingBoundary")
 for cell in border.get_used_cells():
  var p:=border.map_to_local(cell)*border.scale
  for portal in map.get_node("Portals").get_children():
   if portal.destination in targets and p.distance_to(portal.position)<175:border.erase_cell(cell)
 var flora:TileMapLayer=map.get_node("FlowerDrifts")
 for cell in flora.get_used_cells():
  var p:=flora.map_to_local(cell)*flora.scale
  if roads.has(Vector2i(p/32)) or ponds.has(Vector2i(p/32)):flora.erase_cell(cell)
 for body in map.get_children():
  if body is StaticBody2D and (is_equal_approx(body.position.x,16) or is_equal_approx(body.position.y,16) or is_equal_approx(body.position.x,map.map_size.x-16) or is_equal_approx(body.position.y,map.map_size.y-16)):body.free()
 builder.boundaries(links)
 if id=="royal_woods" and map.get_node("Arch6").kind=="arch":
  var arch=map.get_node("Arch6");arch.kind="woodland_arch"
  builder.solid(arch,Vector2(8,12),Vector2(-49,-6));builder.solid(arch,Vector2(8,12),Vector2(49,-6))
 map.set_meta("serpentine_route",true)
 if id=="wonderland_village":
  for i in Layout.BUILDINGS.size():
   var b=Layout.BUILDINGS[i]
   for n in map.find_children("*","Node2D",true,false):
    if n.get_script()==Ornament and n.kind in ["house","mushroom_house","teapot_house","clock_house","pink_house"]:
     var p:Vector2=n.position if n.get_parent()==map else n.position+n.get_parent().position
     if p.distance_to(b.point)<1:n.variant=i
func interiors(id:String) -> void:
 # Preserve v2's compact room footprints and working furniture, correct surface anchoring.
 for n in map.get_children():
  if n.get_script()==Ornament and n.kind=="teapot":n.position.y+=28
  if n.get_script()==Prop and n.kind=="painting":n.z_index=-3
 var walls:TileMapLayer=map.get_node("RoomWalls")
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/wonderland_wall_depth.gdshader");walls.material=material;walls.modulate=Color.WHITE
 map.set_meta("architecture_refined",true)
func tabletop_details() -> void:
 var props:=map.get_children()
 for item in props:
  if item.get_script()!=Ornament or item.kind!="teapot":continue
  var support:Node2D
  var distance:=180.0
  for prop in props:
   if prop.get_script()==Prop and prop.kind=="worktable":
    var d:float=item.position.distance_to(prop.position)
    if d<distance:distance=d;support=prop
  if support!=null:
   var point:Vector2=(item.position-support.position)/support.scale
   var size:Vector2=item.scale/support.scale
   item.owner=null;map.remove_child(item);support.add_child(item);item.position=point;item.scale=size
   item.set_meta("tabletop",true)
 if map.region_id=="teapot_house" and map.has_node("Painting16"):
  map.get_node("Painting16").position=Vector2(665,255)
 if map.region_id=="storytellers_cottage":
  map.get_node("Fireplace11").position=Vector2(850,405)
  map.get_node("Sofa8").position=Vector2(660,450)
 for item in props:
  if item.get_script()==Prop and item.kind=="painting":
   item.variant={"teapot_house":3,"mushroom_cottage":0,"royal_gift_shop":1,"storytellers_cottage":2,"tiny_pink_house":3,"castle_hall":4,"banquet_hall":5}.get(map.region_id,0)
  if item.get_script()==Ornament and item.kind=="bread_rack":
   for body in item.get_children():
    if not body is StaticBody2D:continue
    body.position=Vector2(0,-7)
    for collision in body.get_children():
     if collision is CollisionShape2D:
      collision.shape=collision.shape.duplicate();collision.shape.size=Vector2(28,12)
func run():
 if not OS.get_cmdline_user_args().has("--apply"):quit(1);return
 for id in Layout.regions():
  map=load("res://scenes/wonderland/"+id+".tscn").instantiate();builder=Builder.new();builder.map=map;builder.setup_tiles()
  if Layout.OUTDOORS.has(id):outdoor(id)
  elif not map.get_meta("architecture_refined",false):interiors(id)
  if not Layout.OUTDOORS.has(id):tabletop_details()
  builder.owner_tree(map,map);var packed:=PackedScene.new();packed.pack(map);ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn");map.free();print("REFINED ",id)
 quit()
