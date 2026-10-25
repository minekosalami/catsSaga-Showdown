extends SceneTree
const Plan=preload("res://scripts/wonderland/environment_plan.gd")
const Layout=preload("res://scripts/wonderland/layout.gd")
const Builder=preload("res://scripts/wonderland/builder.gd")
const Prop=preload("res://scripts/wonderland/environment_prop.gd")
const Ornament=preload("res://scripts/wonderland/ornament.gd")
var map: Node2D
var builder: RefCounted
var id: String
var rng:=RandomNumberGenerator.new()
var routes: Array[PackedVector2Array]=[]
var side_routes: Array[PackedVector2Array]=[]
var reserved: Array[Rect2]=[]
var water_cells:Dictionary={}
var tree_points:Array[Vector2]=[]
var planted:Dictionary={}
var stats:Dictionary={}
var hedge_set:TileSet
var flora_set:TileSet
func _initialize() -> void:run.call_deferred()
func set_for_flowers(solid:bool) -> TileSet:
 var set:=TileSet.new();set.tile_size=Vector2i(32,32)
 var source:=TileSetAtlasSource.new();source.texture=preload("res://assets/environment_human/lpc_revised/flowers.png");source.texture_region_size=Vector2i(32,32)
 set.add_source(source,0)
 if solid:set.add_physics_layer();set.set_physics_layer_collision_layer(0,1);set.set_physics_layer_collision_mask(0,2)
 for x in range(6):
  var cell:=Vector2i(x,1);source.create_tile(cell)
  if solid:
   var data:=source.get_tile_data(cell,0);data.set_collision_polygons_count(0,1)
   data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
 return set
func layer(name:String,set:TileSet,z:int,unit:float=32) -> TileMapLayer:
 var node:=TileMapLayer.new();node.name=name;node.tile_set=set;node.scale=Vector2.ONE*unit/set.tile_size.x
 node.z_index=z;node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;map.add_child(node);return node
func distance_to(point:Vector2,lines:Array[PackedVector2Array]) -> float:
 var best:=INF
 for route in lines:
  for i in range(1,route.size()):best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,route[i-1],route[i])))
 return best
func protected(point:Vector2,margin:float=0) -> bool:
 for rect in reserved:
  if rect.grow(margin).has_point(point):return true
 for rect in Plan.CLEARINGS.get(id,[]):
  if rect.grow(margin).has_point(point):return true
 return false
func safe_for_tree(point:Vector2) -> bool:
 if protected(point,32) or water_cells.has(Vector2i(point/32)):return false
 if distance_to(point,routes)<132 or distance_to(point,side_routes)<108:return false
 for other in tree_points:
  if point.distance_squared_to(other)<6800:return false
 return true
func prop(kind:String,point:Vector2,scale:float,variant:int,solid:Vector2=Vector2.ZERO) -> Sprite2D:
 var node:=Prop.new();node.kind=kind;node.variant=variant;node.position=point;node.scale=Vector2.ONE*scale;node.name=kind.to_pascal_case()+str(map.get_child_count())
 map.add_child(node)
 if solid!=Vector2.ZERO:builder.solid(node,solid/scale,Vector2(0,-solid.y*.35/scale))
 return node
func ornament(kind:String,point:Vector2,color:Color=Color.WHITE,solid:Vector2=Vector2.ZERO,variant:int=0) -> Node2D:
 return builder.ornament(kind,point,color,solid,variant)
func dress_buildings() -> void:
 if id=="wonderland_village":
  for b in Layout.BUILDINGS:
   var node:Node2D
   if b.kind.begins_with("house"):node=builder.sprite(b.kind,b.point)
   else:node=ornament(b.kind,b.point,b.color,Vector2(150,64))
   for art in node.find_children("*","Node2D",true,false):
    if art.get_script()==Ornament:art.accent=b.color
   reserved.append(Rect2(b.point+Vector2(-230,-300),Vector2(460,450)))
   var join:Vector2=b.point+Vector2(0,140)
   var closest:=Vector2.ZERO;var distance:=INF
   for route in routes+side_routes:
    for p in route:
     if p.distance_squared_to(join)<distance:distance=p.distance_squared_to(join);closest=p
   side_routes.append(Plan.smooth([b.point+Vector2(0,15),join,closest]))
   for dx in [-110,110]:ornament("flowerpot",b.point+Vector2(dx,28),b.color,Vector2(24,18))
   ornament("lantern",b.point+Vector2(-75,-10))
  ornament("fountain",Vector2(1920,865),Color("#8ad7ff"),Vector2(130,70))
 elif id=="queens_castle":
  ornament("castle",Vector2(1280,860),Color("#ff93d2"))
  builder.solid(map,Vector2(740,400),Vector2(1280,610))
  reserved.append(Rect2(850,250,860,650))
  ornament("fountain",Vector2(1280,1580),Color("#c495ff"),Vector2(110,64))
  for p in [Vector2(760,980),Vector2(1800,980),Vector2(790,1590),Vector2(1750,1590)]:ornament("banner",p,Color("#ec62bf"))
func pond(center:Vector2,radius:Vector2) -> void:
 for y in range(int((center.y-radius.y)/32),int((center.y+radius.y)/32)+1):
  for x in range(int((center.x-radius.x)/32),int((center.x+radius.x)/32)+1):
   var cell:=Vector2i(x,y);var p:=Vector2(cell*32)+Vector2(16,16)
   var shape:Vector2=(p-center)/radius
   if shape.length()<1+.06*sin(x*.8+y*.5) and distance_to(p,routes+side_routes)>105 and not protected(p):water_cells[cell]=true
func paint_outdoor() -> void:
 var ground:=layer("Ground",load("res://resources/wonderland/grass.tres"),-8)
 ground.modulate=Plan.PALETTES[id]
 var road:=layer("GardenPaths",load("res://resources/wonderland/road.tres"),-6)
 var occupied:Dictionary={}
 var dims:=Vector2i(map.map_size/32)
 for y in dims.y:
  for x in dims.x:
   var cell:=Vector2i(x,y);var p:=Vector2(cell*32)+Vector2(16,16)
   ground.set_cell(cell,0,Vector2i(11+(1+x%4 if (x*13+y*29)%67<5 else 0),12))
   if distance_to(p,routes)<76+9*sin(x*.22) or distance_to(p,side_routes)<48:occupied[cell]=true
 for cell:Vector2i in occupied:
  var x:=12;var y:=8
  if not occupied.has(cell+Vector2i.LEFT):x=11
  elif not occupied.has(cell+Vector2i.RIGHT):x=13
  if not occupied.has(cell+Vector2i.UP):y=7
  elif not occupied.has(cell+Vector2i.DOWN):y=9
  road.set_cell(cell,0,Vector2i(x,y))
 var ponds:Dictionary={"wonderland_forest":[[Vector2(360,380),Vector2(210,120)]],"mushroom_thicket":[[Vector2(2080,300),Vector2(170,105)]],"tea_gardens":[[Vector2(2060,540),Vector2(145,105)]],"royal_woods":[[Vector2(2290,850),Vector2(210,130)]],"wonderland_village":[],"queens_castle":[[Vector2(600,1200),Vector2(100,170)],[Vector2(1960,1200),Vector2(100,170)]]}
 for entry in ponds[id]:pond(entry[0],entry[1])
 var water:=layer("FairytaleWater",load("res://resources/wonderland/water.tres"),-7)
 for cell:Vector2i in water_cells:
  var x:=12;var y:=7
  if not water_cells.has(cell+Vector2i.LEFT):x=11
  elif not water_cells.has(cell+Vector2i.RIGHT):x=13
  if not water_cells.has(cell+Vector2i.UP):y=6
  elif not water_cells.has(cell+Vector2i.DOWN):y=8
  water.set_cell(cell,0,Vector2i(x,y))
 stats[id]={"road_tiles":occupied.size(),"water_tiles":water_cells.size()}
func borders() -> void:
 var hedge:=layer("LivingBoundary",hedge_set,-1,48)
 var dims:=Vector2i(map.map_size/48)
 for y in range(dims.y+1):
  for x in range(dims.x+1):
   if x>1 and y>1 and x<dims.x-2 and y<dims.y-2:continue
   var p:=Vector2(x*48+24,y*48+24)
   var opening:=false
   for portal in map.get_node("Portals").get_children():
    if portal.destination!="flooded_forest" and p.distance_to(portal.position)<164:opening=true
   if opening:continue
   hedge.set_cell(Vector2i(x,y),0,Vector2i((x+y)%6,1))
   if (x+y)%3==0:
    var root:=p+Vector2(rng.randf_range(-20,20),-5)
    if not protected(root):prop("mushroom" if id=="mushroom_thicket" else "tree",root,rng.randf_range(3,5) if id=="mushroom_thicket" else rng.randf_range(1.5,2.05),rng.randi_range(0,5))
func vegetation() -> void:
 # Rejection sampling only dresses authored districts; it never chooses geography.
 var district_centers:Array[Vector2]=[map.map_size*Vector2(.18,.28),map.map_size*Vector2(.35,.67),map.map_size*Vector2(.67,.26),map.map_size*Vector2(.82,.74)]
 for i in 3200:
  var center:Vector2=district_centers[i%district_centers.size()]
  var point:Vector2=center+Vector2(rng.randfn(0,map.map_size.x*.19),rng.randfn(0,map.map_size.y*.22))
  if not Rect2(Vector2(95,140),map.map_size-Vector2(190,240)).has_point(point) or not safe_for_tree(point):continue
  tree_points.append(point)
  var type: String="mushroom" if id=="mushroom_thicket" and i%5!=0 else "tree"
  var size:float=rng.randf_range(2.6,4.7) if type=="mushroom" else rng.randf_range(1.45,2.1)
  var variant:int=i%6
  if id=="royal_woods":variant=4+i%2
  elif id in ["tea_gardens","queens_castle"]:variant=2+i%2
  var tree:=prop(type,point,size,variant,Vector2(34,24) if type=="tree" else Vector2(26,20))
  if type=="mushroom":tree.modulate=Color.WHITE
 var flora:=layer("FlowerDrifts",flora_set,-2,40)
 # Small coherent clusters at grove edges, with open paths and clearing interiors.
 for center in tree_points:
  for j in 4:
   var point:Vector2=center+Vector2(rng.randf_range(-90,90),rng.randf_range(20,100))
   var cell:=Vector2i(point/40)
   if protected(point) or distance_to(point,routes)<88 or distance_to(point,side_routes)<64 or water_cells.has(Vector2i(point/32)):continue
   if not Rect2(Vector2(55,55),map.map_size-Vector2(110,110)).has_point(point):continue
   if not planted.has(cell):flora.set_cell(cell,0,Vector2i((cell.x/6+cell.y/5)%6,1));planted[cell]=true
 stats[id]["trees_or_mushrooms"]=tree_points.size()
 stats[id]["flower_clusters"]=planted.size()
func landmarks() -> void:
 match id:
  "wonderland_forest":
   prop("tree",Vector2(1280,840),3.25,3,Vector2(65,40))
   for p in [Vector2(1180,900),Vector2(1390,900),Vector2(1280,965)]:prop("flowers",p,2,2)
   ornament("fountain",Vector2(2370,1250),Color("#c2a6ff"),Vector2(95,55))
  "mushroom_thicket":
   for i in 3:prop("mushroom",Vector2(1720+i*90,600+(i%2)*90),5.5-i*.7,3+i,Vector2(30,24)).modulate=Color("#b5d4ff")
   for i in 5:prop("mushroom",Vector2(610+i*55,1550+sin(i)*40),3.4,3+i%3,Vector2(22,18))
  "tea_gardens":
   for p in [Vector2(510,1480),Vector2(670,1480),Vector2(1830,1490),Vector2(1990,1490)]:prop("flowers",p,2.5,2)
   ornament("grand_teapot",Vector2(590,1430),Color("#f6bd4c"),Vector2(85,45))
   ornament("grand_teacup",Vector2(1910,1440),Color("#68e0cb"),Vector2(85,45))
   for point in [Vector2(730,850),Vector2(1660,800),Vector2(1830,710)]:
    ornament("tea_table",point,Color.WHITE,Vector2(130,70))
    for dx in [-92,92]:ornament("chair",point+Vector2(dx,60),Color.WHITE,Vector2(24,18))
  "royal_woods":
   ornament("arch",Vector2(3200,800),Color("#be8ce9"))
   for p in [Vector2(2980,750),Vector2(3410,750),Vector2(920,980)]:ornament("banner",p,Color("#b086ff"))
   ornament("fountain",Vector2(1390,760),Color("#85e6cf"),Vector2(100,55))
 for portal in map.get_node("Portals").get_children():
  var point:Vector2=portal.position.clamp(Vector2(160,160),map.map_size-Vector2(160,160))
  for dx in [-100,100]:ornament("lantern",point+Vector2(dx,0))
func outdoor() -> void:
 for points in Plan.MAIN[id]:routes.append(Plan.smooth(points))
 for points in Plan.LOOPS[id]:side_routes.append(Plan.smooth(points))
 for entry in map.get_node("Entries").get_children():reserved.append(Rect2(entry.position-Vector2(100,100),Vector2(200,200)))
 for portal in map.get_node("Portals").get_children():reserved.append(Rect2(portal.position-Vector2(110,100),Vector2(220,200)))
 if id=="wonderland_forest":reserved.append(Rect2(1140,1280,560,570)) # Existing Smoki arrival and departure choreography.
 dress_buildings();paint_outdoor();landmarks()
 # Reserve the actual landmarks before planting: canopy must not swallow them.
 for child in map.get_children():
  if child is Node2D and (child.get_script()==Prop or child.get_script()==Ornament):
   reserved.append(Rect2(child.position-Vector2(125,150),Vector2(250,230)))
 borders();vegetation()
 # Short ornamental fence runs frame garden beds, never span a route.
 if id in ["tea_gardens","royal_woods","wonderland_village","queens_castle"]:
  for i in range(0,tree_points.size(),20):
   var p:Vector2=tree_points[i]+Vector2(70,55)
   if distance_to(p,routes+side_routes)>150 and not protected(p,20):prop("fence",p,1.1,0,Vector2(76,15))

func interior() -> void:
 var castle:bool=Layout.CASTLE_ROOMS.has(id)
 var rooms:Array[Rect2]
 if castle:rooms=[Rect2(192,256,896,512)]
 elif id=="teapot_house":rooms=[Rect2(352,352,576,448),Rect2(224,352,128,192),Rect2(928,416,160,256)]
 elif id=="tiny_pink_house":rooms=[Rect2(384,384,512,416)]
 elif id in ["mushroom_cottage","storytellers_cottage"]:rooms=[Rect2(288,320,704,480),Rect2(224,448,64,224)]
 else:rooms=[Rect2(256,288,768,512)]
 var floor_set:=TileSet.new();floor_set.tile_size=Vector2i(32,32)
 var floor_atlas:=TileSetAtlasSource.new();floor_atlas.texture=preload("res://assets/wonderland_human/rebuild/herringbone.png");floor_atlas.texture_region_size=Vector2i(32,32);floor_set.add_source(floor_atlas,0)
 floor_atlas.create_tile(Vector2i(2,0))
 var ground:=layer("Ground",load("res://resources/wonderland/marble.tres") if castle else floor_set,-8)
 var occupied:Dictionary={}
 for y in range(30):
  for x in range(40):
   var point:=Vector2(x*32+16,y*32+16)
   var on_floor:=false
   for room in rooms:
    if room.has_point(point):on_floor=true
   for portal in map.get_node("Portals").get_children():
    var join:=point
    if portal.position.x<100 or portal.position.x>1180:
     if absf(point.y-portal.position.y)<72:on_floor=true
    elif portal.position.y<100:
     if absf(point.x-portal.position.x)<72 and point.y<400:on_floor=true
    elif absf(point.x-portal.position.x)<72 and point.y>650 and point.y<maxf(832,portal.position.y+32):on_floor=true
   if on_floor:
    occupied[Vector2i(x,y)]=true
    ground.set_cell(Vector2i(x,y),0,Vector2i(1,1) if castle else Vector2i(2,0))
 var walls:=TileSet.new();walls.tile_size=Vector2i(16,16);walls.add_physics_layer();walls.set_physics_layer_collision_layer(0,1)
 var source:=TileSetAtlasSource.new();source.texture=preload("res://assets/wonderland_human/rpg/roguelikeSheet_transparent.png");source.texture_region_size=Vector2i(16,16);source.separation=Vector2i(1,1)
 walls.add_source(source,0);source.create_tile(Vector2i(7,2))
 var data:=source.get_tile_data(Vector2i(7,2),0);data.set_collision_polygons_count(0,1);data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)]))
 var back:=layer("RoomWalls",walls,-7);back.modulate=Color("#645366") if castle else Color("#534d5b")
 for y in 30:
  for x in 40:
   if not occupied.has(Vector2i(x,y)):back.set_cell(Vector2i(x,y),0,Vector2i(7,2))
 var wallpaper:=TileSet.new();wallpaper.tile_size=Vector2i(32,32)
 var paper:=TileSetAtlasSource.new();paper.texture=preload("res://assets/wonderland_human/rebuild/wallpaper.png");paper.texture_region_size=Vector2i(32,32);wallpaper.add_source(paper,0)
 var palette:int=3 if castle else {"teapot_house":4,"flower_shop":9,"bakery":8,"tiny_pink_house":9}.get(id,6)
 for y in 3:
  for x in 3:paper.create_tile(Vector2i(palette*3+x,y))
 var facing:=layer("DecorativeWallFacing",wallpaper,-6)
 for cell:Vector2i in occupied:
  if occupied.has(cell+Vector2i.UP):continue
  for y in 3:
   var above:=cell+Vector2i(0,-3+y)
   if above.y>=0 and not occupied.has(above):facing.set_cell(above,0,Vector2i(palette*3+posmod(cell.x,3),y))
 # Composed furnished districts; door lanes remain clear, never invented interactions.
 prop("rug",Vector2(640,700),2,0 if castle else 1).z_index=-5
 if id=="teapot_house":
  prop("cabinet",Vector2(272,440),1.2,1,Vector2(35,24))
  prop("shelf",Vector2(320,440),1.1,2,Vector2(32,22))
  prop("bed",Vector2(1008,570),1.1,1,Vector2(60,64))
  ornament("tea_table",Vector2(630,570),Color.WHITE,Vector2(130,70))
  for p in [Vector2(510,560),Vector2(760,560)]:ornament("chair",p,Color.WHITE,Vector2(24,18))
  prop("fireplace",Vector2(840,470),1.1,0,Vector2(100,40))
 elif id=="throne_room":
  ornament("throne",Vector2(640,350),Color("#cb669e"),Vector2(100,50))
  for x in [330,950]:ornament("banner",Vector2(x,420),Color("#e277ce"))
 elif id in ["royal_library","storytellers_cottage","royal_gift_shop"]:
  for x in [340,440,540,740,840,940]:prop("shelf",Vector2(x,380),1.25,2+int(x/100)%2,Vector2(38,22))
  ornament("writing_desk",Vector2(540,530),Color.WHITE,Vector2(180,40))
  ornament("chair",Vector2(540,600),Color.WHITE,Vector2(24,18))
 elif id=="clockmakers_house":
  for x in [340,480,800,940]:prop("clock",Vector2(x,400),1.2,int(x)%3,Vector2(30,24))
  ornament("workbench",Vector2(490,550),Color.WHITE,Vector2(180,40))
 elif id=="bakery":
  for x in [380,610,850]:prop("fireplace",Vector2(x,430),1.2,0,Vector2(90,40))
  ornament("counter",Vector2(420,600),Color.WHITE,Vector2(160,40),1)
  prop("shelf",Vector2(920,600),1.3,0,Vector2(36,24))
 elif id=="flower_shop":
  for p in [Vector2(340,410),Vector2(480,420),Vector2(800,420),Vector2(940,430),Vector2(350,620)]:
   ornament("flowerpot",p,Color.WHITE,Vector2(25,18));prop("flowers",p-Vector2(0,38),1.6,int(p.x/100)%6)
  ornament("counter",Vector2(850,610),Color.WHITE,Vector2(160,40),2)
 elif id=="banquet_hall":
  for x in [440,850]:
   ornament("tea_table",Vector2(x,410),Color.WHITE,Vector2(130,70))
   for dx in [-80,80]:ornament("chair",Vector2(x+dx,480),Color.WHITE,Vector2(24,18))
 elif id=="castle_hall":ornament("fountain",Vector2(640,360),Color("#b6daff"),Vector2(100,50))
 else:
  prop("bed",Vector2(450,500),1.2,2,Vector2(62,70))
  prop("shelf",Vector2(820,490),1.3,1,Vector2(38,24))
  ornament("tea_table",Vector2(650,570),Color.WHITE,Vector2(130,70))
 # Furnished side bays leave the central door lanes and return routes intact.
 if id in ["castle_hall","throne_room","royal_library"]:
  for x in [340,940]:
   ornament("chair",Vector2(x,640),Color.WHITE,Vector2(24,18))
   prop("cabinet",Vector2(x,310),1.1,1,Vector2(34,24))
   ornament("lantern",Vector2(x+55,650))
 elif id in ["clockmakers_house","royal_gift_shop","storytellers_cottage"]:
  prop("fireplace",Vector2(900,620),1,0,Vector2(85,35))
  ornament("chair",Vector2(795,650),Color.WHITE,Vector2(24,18))
 if id in ["teapot_house","mushroom_cottage","tiny_pink_house"]:
  for p in [Vector2(450,630),Vector2(830,610)]:ornament("flowerpot",p,Color.WHITE,Vector2(22,18));prop("flowers",p-Vector2(0,37),1.3,3)
 for p in [Vector2(420,700),Vector2(850,700)]:ornament("flowerpot",p,Color.WHITE,Vector2(22,18))
 for x in [460,820]:ornament("window",Vector2(x,rooms[0].position.y+5)).z_index=1
 map.set_meta("camera_bounds",Rect2(0,120,1280,720))
 stats[id]={"floor_tiles":occupied.size()}
func run() -> void:
 if not OS.get_cmdline_user_args().has("--apply"):push_error("Use -- --apply");quit(1);return
 hedge_set=set_for_flowers(true);flora_set=set_for_flowers(false)
 ResourceSaver.save(hedge_set,"res://resources/wonderland/living_boundary.tres")
 ResourceSaver.save(flora_set,"res://resources/wonderland/flower_drifts.tres")
 hedge_set=load("res://resources/wonderland/living_boundary.tres");flora_set=load("res://resources/wonderland/flower_drifts.tres")
 for region in Layout.regions():
  id=region;map=load("res://scenes/wonderland/"+id+".tscn").instantiate()
  routes.clear();side_routes.clear();reserved.clear();tree_points.clear();water_cells.clear();planted.clear()
  rng.seed=hash(id+Plan.REVISION)
  # Entries, portals, existing interactables and their text survive the rebuild.
  for child in map.get_children():
   if child.name in ["Entries","Portals"] or child is Label or child.has_method("handle_interaction"):continue
   child.free()
  map.remove_meta("camera_focus")
  builder=Builder.new();builder.map=map;builder.setup_tiles()
  if Layout.OUTDOORS.has(id):outdoor()
  else:interior()
  var ambience=load("res://scripts/wonderland/ambience.gd").new();ambience.name="WonderlandAmbience";ambience.indoor=not Layout.OUTDOORS.has(id);map.add_child(ambience)
  map.set_meta(Plan.REVISION,true)
  builder.owner_tree(map,map)
  var packed:=PackedScene.new();packed.pack(map);ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn")
  print("REBUILT ",id," ",stats[id]);map.free()
 var file:=FileAccess.open("res://docs/review/wonderland-rebuild/layout-statistics.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"\t"))
 quit()
