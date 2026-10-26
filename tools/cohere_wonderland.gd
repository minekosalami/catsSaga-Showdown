extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
const Prop=preload("res://scripts/wonderland/environment_prop.gd")
const Ornament=preload("res://scripts/wonderland/ornament.gd")
const Builder=preload("res://scripts/wonderland/builder.gd")
var map:Node2D
var helper:RefCounted
var changes:Dictionary={}
func _initialize() -> void:run.call_deferred()
func layer(name:String,texture:Texture2D,unit:int,z:int,physics:=false) -> TileMapLayer:
 var tiles:=TileSet.new();tiles.tile_size=Vector2i(unit,unit)
 var atlas:=TileSetAtlasSource.new();atlas.texture=texture;atlas.texture_region_size=Vector2i(unit,unit);tiles.add_source(atlas,0)
 if physics:tiles.add_physics_layer();tiles.set_physics_layer_collision_layer(0,1);tiles.set_physics_layer_collision_mask(0,2)
 var node:=TileMapLayer.new();node.name=name;node.tile_set=tiles;node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;node.z_index=z;map.add_child(node);return node
func cell(node:TileMapLayer,p:Vector2i,uv:Vector2i) -> void:
 var atlas=node.tile_set.get_source(0) as TileSetAtlasSource
 if not atlas.has_tile(uv):
  atlas.create_tile(uv)
  if node.tile_set.get_physics_layers_count()>0:
   var data:=atlas.get_tile_data(uv,0);var h:float=node.tile_set.tile_size.x*.5;data.set_collision_polygons_count(0,1);data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-h,-h),Vector2(h,-h),Vector2(h,h),Vector2(-h,h)]))
 node.set_cell(p,0,uv)
func transitions(old:TileMapLayer,water:bool,ground:TileMapLayer) -> void:
 # Retain occupied geography. Four source-art quarters cover all convex/concave cases.
 if old.get_meta("world_cell_size",32)==16:
  old.modulate=Color.WHITE
  old.material.set_shader_parameter("grass_color",Vector3(116,163,52)/255.0*Vector3(ground.modulate.r,ground.modulate.g,ground.modulate.b));old.material.set_shader_parameter("source_green",188.0/255 if water else 163.0/255)
  return
 var occupied:Dictionary={}
 for p in old.get_used_cells():occupied[p]=true
 var old_name:=str(old.name);var old_z:=old.z_index;map.remove_child(old);old.free()
 var texture:Texture2D=load("res://assets/wonderland_human/ninja/Floor.png" if water else "res://assets/wonderland_human/ninja/tileset_floor.png")
 var half:=32 if water else 8
 var target:=layer(old_name,texture,half,old_z,water);target.scale=Vector2.ONE*16/half;target.modulate=Color.WHITE
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/wonderland_terrain.gdshader");material.set_shader_parameter("grass_color",Vector3(116,163,52)/255.0*Vector3(ground.modulate.r,ground.modulate.g,ground.modulate.b));material.set_shader_parameter("source_green",188.0/255 if water else 163.0/255);target.material=material
 var top:=6 if water else 7
 for p:Vector2i in occupied:
  for qy in 2:
   for qx in 2:
    var sx:Vector2i=Vector2i(-1 if qx==0 else 1,0);var sy:Vector2i=Vector2i(0,-1 if qy==0 else 1)
    var h:bool=occupied.has(p+sx);var v:bool=occupied.has(p+sy)
    var source:=Vector2i(12,top+1)
    if not h:source.x=11 if qx==0 else 13
    if not v:source.y=top if qy==0 else top+2
    if h and v and not occupied.has(p+sx+sy):
     source=Vector2i(18 if qx==0 else 19,top+2) if qy==0 else Vector2i(17 if qx==0 else 20,top+1)
    cell(target,p*2+Vector2i(qx,qy),source*2+Vector2i(qx,qy))
 # Remember occupancy convention for walkability: this layer now has 16px world cells.
 target.set_meta("world_cell_size",16)
func overlaps_path(rect:Rect2,paths:TileMapLayer) -> bool:
 var a:=Vector2i(rect.position/16);var b:=Vector2i(rect.end/16)
 for y in range(a.y,b.y+1):
  for x in range(a.x,b.x+1):
   if paths.get_cell_source_id(Vector2i(x,y))>=0:return true
 return false
func outdoor(id:String) -> void:
 var ground:TileMapLayer=map.get_node("Ground")
 transitions(map.get_node("GardenPaths"),false,ground);transitions(map.get_node("FairytaleWater"),true,ground)
 var paths:TileMapLayer=map.get_node("GardenPaths");var moved:=0
 for art in map.get_children():
  if art.get_script()!=Prop or art.kind not in ["tree","mushroom"]:continue
  if id=="wonderland_forest" and art.position.distance_to(Vector2(1280,840))<10:continue
  if not art.has_meta("cohesion_original_position"):
   art.set_meta("cohesion_original_position",art.position);art.set_meta("cohesion_original_scale",art.scale)
  art.position=art.get_meta("cohesion_original_position");art.scale=art.get_meta("cohesion_original_scale")
  var start:Vector2=art.position
  var footprint:Rect2=art.get_rect();footprint.position*=art.scale;footprint.size*=art.scale
  # The lower body remains y-sorted; reserve visual canopy clearance above routes.
  if not overlaps_path(Rect2(start+footprint.position+Vector2(16,0),footprint.size-Vector2(32,30)),paths):continue
  var found:=false
  for radius in [32,64,96,128,160,192,224,256]:
   if found:break
   for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
    var candidate:Vector2=start+direction*radius
    if not Rect2(Vector2(105,160),map.map_size-Vector2(210,260)).has_point(candidate):continue
    if id=="wonderland_forest" and Rect2(1140,1280,560,570).has_point(candidate):continue
    if not map.is_walkable_position(candidate):continue
    var water:TileMapLayer=map.get_node("FairytaleWater")
    var wet:=false
    for sample in [Vector2.ZERO,Vector2(0,-90),Vector2(-45,-70),Vector2(45,-70)]:
     if water.get_cell_source_id(water.local_to_map(water.to_local(map.to_global(candidate+sample))))>=0:wet=true
    if wet:continue
    if overlaps_path(Rect2(candidate+footprint.position,footprint.size),paths):continue
    var near:=false
    for other in map.get_children():
     if other==art or not other is Node2D:continue
     if other.get_script()==Prop and other.position.distance_to(candidate)<55:near=true;break
     if other.get_script()==Ornament and other.position.distance_to(candidate)<130:near=true;break
    if near:continue
    art.position=candidate;found=true;moved+=1;break
  # An isolated obstruction that cannot be moved keeps its trunk, but is reduced one step.
  if not found and art.kind=="tree" and art.scale.x>1.5:art.scale=Vector2.ONE*1.5
 changes[id]={"canopies_repositioned":moved,"path_quarters":paths.get_used_cells().size()}
func prop(kind:String,p:Vector2,variant:=0,size:=Vector2.ZERO) -> Sprite2D:
 var art:=Prop.new();art.kind=kind;art.variant=variant;art.position=p;art.scale=Vector2.ONE*2;art.name=kind.to_pascal_case()+str(map.get_child_count());map.add_child(art)
 if size!=Vector2.ZERO:
  if kind=="worktable":size.x=140
  if kind=="shopcounter":size.x=224
  helper.solid(art,size/2,Vector2(0,-size.y*.25))
 return art
func decor(kind:String,p:Vector2,color:=Color.WHITE,size:=Vector2.ZERO) -> Node2D:return helper.ornament(kind,p,color,size)
func interior(id:String) -> void:
 for child in map.get_children():
  if child.name in ["Entries","Portals"] or child is Label or child.has_method("handle_interaction"):continue
  child.free()
 var defs:Dictionary={
 "teapot_house":[Rect2(384,384,512,384),Rect2(192,448,192,192),Rect2(896,448,192,256),Rect2(448,256,320,128)],
 "tiny_pink_house":[Rect2(448,448,384,320),Rect2(704,320,128,128)],
 "mushroom_cottage":[Rect2(320,384,640,384),Rect2(512,256,256,128)],
 "storytellers_cottage":[Rect2(320,384,640,384),Rect2(256,320,192,192)],
 "flower_shop":[Rect2(256,384,768,384),Rect2(320,256,256,128)],
 "clockmakers_house":[Rect2(320,384,640,384),Rect2(320,256,256,128),Rect2(832,320,128,64)],
 "bakery":[Rect2(256,384,768,384),Rect2(256,256,256,128),Rect2(832,256,192,128)],
 "royal_gift_shop":[Rect2(320,384,640,384),Rect2(768,256,192,128)],
 "castle_hall":[Rect2(192,384,896,384),Rect2(448,256,384,128)],
 "royal_library":[Rect2(256,320,768,448),Rect2(384,256,256,64)],
 "banquet_hall":[Rect2(256,320,768,448),Rect2(704,256,256,64)],
 "throne_room":[Rect2(320,320,640,448),Rect2(448,192,384,128)]}
 var rooms:Array=defs[id].duplicate()
 for portal in map.get_node("Portals").get_children():
  var p:Vector2=portal.position
  if p.x<100:rooms.append(Rect2(0,p.y-64,384,128))
  elif p.x>1180:rooms.append(Rect2(896,p.y-64,384,128))
  elif p.y<100:rooms.append(Rect2(p.x-64,0,128,448))
  else:rooms.append(Rect2(p.x-64,640,128,maxf(192,p.y-608)))
 var castle:bool=Layout.CASTLE_ROOMS.has(id)
 var ground:=layer("Ground",load("res://assets/wonderland_human/cohesion/tiles.png" if castle or id in ["bakery","flower_shop"] else "res://assets/wonderland_human/cohesion/wood.png"),32,-8);ground.scale=Vector2.ONE*2
 var walls:=layer("RoomWalls",load("res://assets/wonderland_human/cohesion/tiles.png"),32,-7,true);walls.scale=Vector2.ONE*2;walls.modulate=Color("#4a3546")
 var face:=layer("DecorativeWallFacing",load("res://assets/wonderland_human/rebuild/wallpaper.png"),32,-6);face.scale=Vector2.ONE*2
 var trim:=layer("Wainscot",load("res://assets/wonderland_human/cohesion/paneling.png"),32,-5);trim.scale=Vector2.ONE*2
 var occupied:Dictionary={}
 var palette:int={"teapot_house":0,"mushroom_cottage":6,"tiny_pink_house":9,"flower_shop":4,"bakery":0,"clockmakers_house":7,"royal_gift_shop":8,"storytellers_cottage":6,"castle_hall":3,"royal_library":6,"banquet_hall":8,"throne_room":3}[id]
 for y in 15:
  for x in 20:
   var p:=Vector2(x*64+32,y*64+32);var floor_here:=false
   for room:Rect2 in rooms:
    if room.has_point(p):floor_here=true;break
   if floor_here:
    occupied[Vector2i(x,y)]=true
    var uv:=Vector2i(0,0) if castle else (Vector2i(3,0) if id=="bakery" else (Vector2i(1,0) if id=="flower_shop" else Vector2i(2 if id in ["teapot_house","tiny_pink_house"] else 1,1+(y%2))))
    cell(ground,Vector2i(x,y),uv)
   else:cell(walls,Vector2i(x,y),Vector2i(2,2))
 for p:Vector2i in occupied:
  if occupied.has(p+Vector2i.UP):continue
  for h in 2:
   var above:=p+Vector2i(0,-2+h)
   if above.y<0 or occupied.has(above):continue
   cell(face,above,Vector2i(palette*3+posmod(p.x,3),h))
  cell(trim,p+Vector2i.UP,Vector2i(posmod(p.x,3),0 if castle else 1))
 ground.modulate=Color("#fff0dc")
 var lighting:=ShaderMaterial.new();lighting.shader=preload("res://shaders/wonderland_room_depth.gdshader")
 var rects:=PackedVector4Array()
 for room:Rect2 in rooms:rects.append(Vector4(room.position.x,room.position.y,room.size.x,room.size.y))
 lighting.set_shader_parameter("floor_rooms",rects);lighting.set_shader_parameter("room_count",rects.size());ground.material=lighting
 var a=load("res://scripts/wonderland/ambience.gd").new();a.name="WonderlandAmbience";a.indoor=true;map.add_child(a)
 furnish(id)
 map.set_meta("camera_bounds",Rect2(0,0,1280,960))
 changes[id]={"floor_cells_64px":occupied.size(),"rooms":defs[id].size()}
func carpet(rect:Rect2,palette:int) -> void:
 var node:=layer("Carpet"+str(map.get_child_count()),load("res://assets/wonderland_human/cohesion/carpet.png"),32,-5);node.scale=Vector2.ONE*2
 var origin:=Vector2i(rect.position/64);var size:=Vector2i(rect.size/64)
 for y in size.y:
  for x in size.x:cell(node,origin+Vector2i(x,y),Vector2i((palette%5)*7+(1 if x==0 else (3 if x==size.x-1 else 2)),(palette/5)*3+(0 if y==0 else (2 if y==size.y-1 else 1))))
func furnish(id:String) -> void:
 match id:
  "teapot_house":
   carpet(Rect2(448,448,320,192),1);prop("sofa",Vector2(530,445),0,Vector2(100,45));prop("worktable",Vector2(680,600),2,Vector2(120,60));prop("chair",Vector2(790,630),0,Vector2(38,30))
   prop("stove",Vector2(256,550),0,Vector2(48,50));prop("cabinet",Vector2(352,520),2,Vector2(46,40));prop("bed",Vector2(995,650),1,Vector2(94,100));prop("clock",Vector2(720,380),0,Vector2(38,28));decor("teapot",Vector2(675,525));prop("painting",Vector2(555,330))
  "tiny_pink_house":
   carpet(Rect2(512,576,256,128),6);prop("bed",Vector2(505,600),5,Vector2(80,85));prop("vanity",Vector2(770,445),0,Vector2(82,40));prop("worktable",Vector2(730,640),2,Vector2(105,55));prop("chair",Vector2(740,710),7,Vector2(35,24));prop("painting",Vector2(620,425))
  "mushroom_cottage":
   carpet(Rect2(448,512,384,128),4);prop("bed",Vector2(405,550),3,Vector2(85,90));prop("sofa",Vector2(660,445),3,Vector2(100,45));prop("worktable",Vector2(735,610),1,Vector2(125,55));prop("shelf",Vector2(880,540),2,Vector2(48,34));prop("mushroom",Vector2(610,335),2,Vector2(36,28));prop("painting",Vector2(450,345))
  "flower_shop":
   carpet(Rect2(576,576,320,128),1);prop("shopcounter",Vector2(820,560),0,Vector2(164,45));prop("cabinet",Vector2(930,435),1,Vector2(48,34))
   for p in [Vector2(350,420),Vector2(460,340),Vector2(390,610),Vector2(930,690),Vector2(300,720)]:decor("flowerpot",p,Color.WHITE,Vector2(30,24));prop("flowers",p-Vector2(0,24),int(p.x/100)%6)
   prop("worktable",Vector2(450,540),1,Vector2(125,55))
  "clockmakers_house":
   carpet(Rect2(576,576,320,128),2);prop("worktable",Vector2(475,550),0,Vector2(125,60));prop("chair",Vector2(470,630),5,Vector2(38,26));prop("shopcounter",Vector2(800,500),0,Vector2(164,48));prop("shelf",Vector2(920,700),1,Vector2(45,30))
   for p in [Vector2(370,370),Vector2(530,370),Vector2(885,405)]:prop("clock",p,0,Vector2(38,28))
  "bakery":
   carpet(Rect2(448,640,448,64),0)
   for p in [Vector2(320,375),Vector2(420,375),Vector2(900,375)]:prop("stove",p,0,Vector2(48,40))
   prop("shopcounter",Vector2(820,560),0,Vector2(164,50));prop("worktable",Vector2(445,560),1,Vector2(125,60));decor("bread_rack",Vector2(965,690),Color.WHITE,Vector2(90,34));decor("bread_rack",Vector2(300,650),Color.WHITE,Vector2(90,34))
  "royal_gift_shop":
   carpet(Rect2(448,512,384,192),0);prop("shopcounter",Vector2(805,590),0,Vector2(164,50));prop("cabinet",Vector2(420,455),1,Vector2(48,34));prop("shelf",Vector2(880,370),1,Vector2(48,34));prop("worktable",Vector2(510,610),2,Vector2(120,56));decor("teapot",Vector2(510,540));prop("painting",Vector2(680,365))
  "storytellers_cottage":
   carpet(Rect2(448,512,384,192),4);prop("sofa",Vector2(775,455),2,Vector2(100,45));prop("worktable",Vector2(715,620),0,Vector2(120,50));prop("chair",Vector2(805,680),2,Vector2(38,26));prop("fireplace",Vector2(850,520),0,Vector2(100,45))
   for p in [Vector2(300,410),Vector2(390,410),Vector2(490,460)]:prop("shelf",p,3,Vector2(48,30))
   prop("painting",Vector2(620,370))
  "castle_hall":
   carpet(Rect2(576,384,128,384),3);decor("fountain",Vector2(640,350),Color.WHITE,Vector2(100,48))
   for p in [Vector2(330,445),Vector2(940,700)]:prop("sofa",p,2,Vector2(100,45))
   for p in [Vector2(350,700),Vector2(925,390)]:prop("cabinet",p,1,Vector2(48,36));decor("lantern",p+Vector2(70,0))
   prop("painting",Vector2(900,335))
  "royal_library":
   carpet(Rect2(448,512,448,192),4)
   for p in [Vector2(360,350),Vector2(445,350),Vector2(530,350),Vector2(760,350),Vector2(845,350),Vector2(930,350),Vector2(340,650),Vector2(940,675)]:prop("shelf",p,2,Vector2(48,30))
   for p in [Vector2(530,600),Vector2(820,610)]:prop("worktable",p,0,Vector2(120,55));prop("chair",p+Vector2(0,75),2,Vector2(38,26))
   prop("sofa",Vector2(610,410),3,Vector2(100,45))
  "banquet_hall":
   carpet(Rect2(384,384,512,320),0)
   for p in [Vector2(465,530),Vector2(805,650)]:
    decor("tea_table",p,Color.WHITE,Vector2(130,70))
    for dx in [-110,110]:prop("chair",p+Vector2(dx,0),0,Vector2(38,26))
   prop("shopcounter",Vector2(820,350),0,Vector2(164,42));prop("cabinet",Vector2(960,700),2,Vector2(48,32));prop("painting",Vector2(555,300))
  "throne_room":
   carpet(Rect2(512,256,256,512),3);prop("throne",Vector2(640,320),2,Vector2(80,45));prop("cabinet",Vector2(400,440),1,Vector2(48,34));prop("cabinet",Vector2(880,440),1,Vector2(48,34))
   for p in [Vector2(450,625),Vector2(830,625)]:prop("sofa",p,1,Vector2(100,45))
   for p in [Vector2(490,320),Vector2(790,320),Vector2(360,740),Vector2(920,740)]:decor("banner",p,Color("#9a72cb"));decor("lantern",p+Vector2(40,0))
 # Windows fit wall bays rather than repeating the same plant/rug template.
 var windows:Dictionary={"teapot_house":[Vector2(520,255),Vector2(1000,445)],"tiny_pink_house":[Vector2(770,320)],"mushroom_cottage":[Vector2(620,255)],"flower_shop":[Vector2(440,255),Vector2(850,380)],"clockmakers_house":[Vector2(450,255)],"bakery":[Vector2(640,380)],"royal_gift_shop":[Vector2(865,255)],"storytellers_cottage":[Vector2(350,320)],"castle_hall":[Vector2(520,255),Vector2(760,255)],"royal_library":[Vector2(480,255)],"banquet_hall":[Vector2(830,255)],"throne_room":[Vector2(520,190),Vector2(760,190)]}
 for p in windows[id]:
  var window=decor("window",p);window.z_index=-3;window.variant=1 if Layout.CASTLE_ROOMS.has(id) else 2
 for portal in map.get_node("Portals").get_children():decor("interior_door",portal.position).z_index=1
func run() -> void:
 if not OS.get_cmdline_user_args().has("--apply"):push_error("Explicit -- --apply required");quit(1);return
 for id in Layout.regions():
  map=load("res://scenes/wonderland/"+id+".tscn").instantiate();helper=Builder.new();helper.map=map;helper.setup_tiles()
  if Layout.OUTDOORS.has(id):outdoor(id)
  else:interior(id)
  var previous_depth=map.get_node_or_null("EnvironmentalDepth")
  if previous_depth!=null:previous_depth.free()
  var depth=load("res://scripts/wonderland/depth.gd").new();depth.name="EnvironmentalDepth";map.add_child(depth)
  helper.owner_tree(map,map);var packed:=PackedScene.new();packed.pack(map);ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn");print("COHERED ",id);map.free()
 var file:=FileAccess.open("res://docs/review/wonderland-v2/layout.json",FileAccess.WRITE);file.store_string(JSON.stringify(changes,"\t"));quit()
