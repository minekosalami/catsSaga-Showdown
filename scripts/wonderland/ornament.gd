@tool
extends Node2D
## Atlas-only level decoration. Every rendered pixel comes from credited human art.
## No shape drawing, generated textures, or image synthesis belongs in this component.
@export var kind := "flowers":
 set(value):
  kind = value
  queue_redraw()
@export var accent := Color.WHITE:
 set(value):
  accent = value
  queue_redraw()
@export var variant := 0:
 set(value):
  variant = value
  queue_redraw()
@export var footprint := Vector2(96,112):
 set(value):
  footprint = value
  queue_redraw()
@export var visual_offset := Vector2.ZERO:
 set(value):
  visual_offset = value
  queue_redraw()
const ORNATE_TABLE=preload("res://assets/wonderland_human/rebuild/ornate_table.png")
const OUTDOOR_LIGHT=preload("res://assets/wonderland_human/rebuild/lighting.png")
const SHINGLES=preload("res://assets/wonderland_human/rebuild/hipped_roof.png")
const SIDING=preload("res://assets/wonderland_human/rebuild/cottage_wall.png")
const DETAILS = preload("res://assets/wonderland_human/ninja/details.png")
const MINT_TREE = preload("res://assets/wonderland_human/ninja/tree_03.png")
const ROUND_TREE = preload("res://assets/wonderland_human/ninja/tree_04.png")
const DAISY = preload("res://assets/wonderland_human/ninja/tileset_animated.png")
const FOREST = preload("res://assets/wonderland_human/ninja/tileset_village_abandoned.png")
const LEAF = preload("res://assets/wonderland_human/ninja/particle_leaf_pink.png")
const RPG = preload("res://assets/wonderland_human/rpg/roguelikeSheet_transparent.png")
const INDOOR = preload("res://assets/wonderland_human/indoor/roguelikeIndoor_transparent.png")
const DUNGEON = preload("res://assets/wonderland_human/dungeon/roguelikeDungeon_transparent.png")
const ONEBIT = preload("res://assets/wonderland_human/onebit/monochrome_transparent_packed.png")
var clock := 0.0
func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 add_to_group("wonderland_ornaments")
 if kind == "fountain":
  var blend := ShaderMaterial.new()
  blend.shader = preload("res://shaders/wonderland_fountain.gdshader")
  material = blend
func tick(time: float) -> void:
 clock = time
 queue_redraw()
func tile(sheet: Texture2D,cell: Vector2i,point: Vector2,zoom := 1.0,tint := Color.WHITE) -> void:
 var stride := 16 if sheet == ONEBIT else 17
 draw_texture_rect_region(sheet,Rect2(point,Vector2.ONE*16*zoom),Rect2(Vector2(cell*stride),Vector2.ONE*16),tint)
func patch(sheet: Texture2D,cell: Vector2i,size: Vector2i,point: Vector2,zoom := 1.0,tint := Color.WHITE) -> void:
 for y in size.y:
  for x in size.x: tile(sheet,cell+Vector2i(x,y),point+Vector2(x,y)*16*zoom,zoom,tint)
func panel(sheet: Texture2D,cell: Vector2i,size: Vector2i,point: Vector2,tint := Color.WHITE) -> void:
 for y in size.y:
  for x in size.x:
   var sx := 0 if x == 0 else (2 if x == size.x-1 else 1)
   var sy := 0 if y == 0 else (2 if y == size.y-1 else 1)
   tile(sheet,cell+Vector2i(sx,sy),point+Vector2(x,y)*16,1,tint)
func table(width: int,tea := true) -> void:
 if tea:
  draw_texture_rect_region(ORNATE_TABLE,Rect2(-40,-112,80,112),Rect2(104,16,80,112))
  draw_texture_rect_region(ORNATE_TABLE,Rect2(-24,-80,48,64),Rect2(40,64,48,64))
  return
 var length := maxi(3,width/2)
 for x in length:
  tile(INDOOR,Vector2i(0 if x == 0 else (2 if x == length-1 else 1),0),Vector2((x-length*.5)*32,-32),2)
 if tea:
  for x in range(1,width,2):
   tile(RPG,Vector2i(56,16),Vector2((x-width*.5)*16,-35))
   tile(RPG,Vector2i(55,13),Vector2((x-width*.5)*16,-24))
  tile(RPG,Vector2i(55,15),Vector2(-8,-40))
func masonry(size: Vector2i,point: Vector2,tint := Color.WHITE) -> void:
 for y in size.y:
  for x in size.x:tile(RPG,Vector2i(7,2),point+Vector2(x,y)*16,1,tint)
func roof(rows: int,base: Vector2,tint: Color) -> void:
 # Matched human-drawn left/right slopes and opaque interior tiles.
 for y in rows:
  var left: Vector2 = base+Vector2(-(y+1)*16,-(rows-y)*16)
  tile(RPG,Vector2i(27,21),left,1,tint)
  for x in range(1,(y+1)*2-1):draw_texture_rect_region(SHINGLES,Rect2(left+Vector2(x*16,0),Vector2(16,16)),Rect2(40+posmod(x,4)*16,16+posmod(y,4)*16,16,16),tint)
  tile(RPG,Vector2i(28,21),left+Vector2(((y+1)*2-1)*16,0),1,tint)
func furniture_shelf(books := true) -> void:
 for y in range(3):
  for x in range(4):tile(RPG,Vector2i(41+x%3,12 if books else 13),Vector2(-32+x*16,-48+y*16))
func house(style := "house") -> void:
 var width := maxi(4,roundi(footprint.x/16))
 var height := maxi(3,roundi(footprint.y/16)-width/2-1)
 var left := roundf(visual_offset.x-width*8)
 var top := -height*16.0
 for y in height:
  for x in width:draw_texture_rect_region(SIDING,Rect2(left+x*16,top+y*16,16,16),Rect2(640+16+posmod(x,7)*16,posmod(y,5)*16,16,16),Color("#fff1d9"))
 roof(width/2+1,Vector2(visual_offset.x,top),accent.lightened(.2))
 for x in range(width):tile(RPG,Vector2i(39,8),Vector2(left+x*16,top+2),1,Color("#e0c2a8"))
 tile(RPG,Vector2i(27,5),Vector2(left+16,top-32))
 tile(RPG,Vector2i(41,24),Vector2(left+8,-25))
 tile(RPG,Vector2i(41,24),Vector2(left+width*16-24,-25))
 for x in [left,left+width*16-32]:
  if absf(x+16)>30:tile(RPG,Vector2i(40,4),Vector2(x,-48),2)
 tile(RPG,Vector2i(32,0),Vector2(-16,-32),2)
 if style == "teapot_house":tile(RPG,Vector2i(55,15),Vector2(visual_offset.x-24,top-48),3)
 if style == "clock_house":
  tile(RPG,Vector2i(26,8),Vector2(visual_offset.x-16,top-40),2)
  tile(ONEBIT,Vector2i(19,14),Vector2(visual_offset.x-8,top-26))
 if style == "mushroom_house":
  for x in [left+4,left+width*16-36]:tile(RPG,Vector2i(48,4),Vector2(x,top-16),2)
 if style == "pink_house":
  for x in [left+16,left+width*16-32]:tile(RPG,Vector2i(41,24),Vector2(x,-29))
func castle() -> void:
 masonry(Vector2i(23,10),Vector2(-184,-176),Color("#ffe2f0"))
 for x in range(-11,12):tile(RPG,Vector2i(16,14),Vector2(x*16-8,-192))
 for side in [-1,1]:
  var x: float = side*152-24
  masonry(Vector2i(3,12),Vector2(x,-208),Color("#ffe0ed"))
  roof(2,Vector2(x+24,-208),Color("#ed9cce"))
  for y in [-184,-136,-88]:tile(RPG,Vector2i(40,4),Vector2(x+8,y),2)
  tile(RPG,Vector2i(53,0),Vector2(x+24,-248),1,Color("#f9b3df"))
 masonry(Vector2i(9,11),Vector2(-72,-192),Color("#ffe8f2"))
 roof(5,Vector2(0,-192),Color("#f3b2db"))
 for x in [-128,-64,32,96]:tile(RPG,Vector2i(40,4),Vector2(x,-144),2)
 tile(RPG,Vector2i(45,0),Vector2(-16,-188),2)
 for x in [-99,83]:patch(RPG,Vector2i(50,3),Vector2i(1,3),Vector2(x,-96),1,Color("#facde6"))
func _draw() -> void:
 match kind:
  "tree":
   var zoom := 1.1+float(absi(variant)%3)*.1
   if absi(variant)%3 == 1:
    draw_texture_rect(MINT_TREE,Rect2(-26*zoom,-51*zoom,52*zoom,52*zoom),false)
   elif absi(variant)%3 == 2:
    draw_texture_rect(ROUND_TREE,Rect2(-25*zoom,-49*zoom,50*zoom,50*zoom),false)
   else:draw_texture_rect_region(FOREST,Rect2(Vector2(-24,-47)*zoom,Vector2(48,48)*zoom),Rect2(0,96,48,48))
  "grove":
   for x in [-22,18]:draw_texture_rect_region(FOREST,Rect2(Vector2(x-24,-58),Vector2(58,58)),Rect2(0,144,48,48))
  "bush":draw_texture_rect_region(FOREST,Rect2(-24,-47,48,48),Rect2(64,144,32,32))
  "house","mushroom_house","teapot_house","clock_house","pink_house":house(kind)
  "flowers":
   var color_index := 41 if accent.b>accent.g else (42 if accent.r>accent.b else 44)
   for p in [Vector2(-16,-16),Vector2(0,-24),Vector2(12,-10)]:
    if variant%3 == 0:draw_texture_rect_region(DAISY,Rect2(p,Vector2.ONE*16),Rect2((int(clock*3)+absi(variant))%4*16,0,16,16))
    else:tile(RPG,Vector2i(color_index,24),p)
  "roses":
   for p in [Vector2(-16,-16),Vector2(0,-24),Vector2(12,-10)]:tile(RPG,Vector2i(29,9),p)
  "leaf_litter":
   for p in [Vector2(-28,0),Vector2(8,-8),Vector2(21,5)]:draw_texture_rect_region(LEAF,Rect2(p,Vector2(9,5.25)),Rect2(0,0,12,7))
  "giant_flower":tile(RPG,Vector2i(41+absi(variant)%4,24),Vector2(-16,-48),2)
  "mushroom":
   var zoom: float = [8.0,5.0,3.0][absi(variant)%3]
   tile(RPG,Vector2i(48,3+absi(variant)%3),Vector2(-7.5*zoom,-16*zoom),zoom)
  "great_tree":
   draw_texture_rect_region(FOREST,Rect2(-24,-240,48,240),Rect2(96,96,16,80))
   for p in [Vector2(-135,-205),Vector2(4,-205),Vector2(-70,-282),Vector2(-64,-195)]:
    draw_texture_rect_region(FOREST,Rect2(p,Vector2(144,96)),Rect2(0,96,48,32))
   for x in [-90,90]:tile(RPG,Vector2i(41,24),Vector2(x,-112),2)
  "teapot":tile(RPG,Vector2i(55,15),Vector2(-16,-32),2)
  "grand_teapot":tile(RPG,Vector2i(55,15),Vector2(-32,-64),4)
  "grand_teacup":tile(RPG,Vector2i(56,16),Vector2(-32,-64),4)
  "tea_table":table(8)
  "banquet_table":table(12)
  "chair":tile(INDOOR,Vector2i(1,3),Vector2(-16,-32),2)
  "bed":tile(INDOOR,Vector2i(10,7),Vector2(-24,-48),3)
  "counter":
   for x in range(6):tile(INDOOR,Vector2i(1+x%3,13),Vector2(-48+x*16,-16))
   if variant == 1:
    for x in [-28,4,25]:tile(RPG,Vector2i(55,13),Vector2(x,-28))
   elif variant == 2:
    for x in [-28,4,25]:tile(INDOOR,Vector2i(16,0),Vector2(x,-30))
   else:
    for x in [-28,4,25]:tile(RPG,Vector2i(40,15),Vector2(x,-30))
  "workbench","writing_desk":
   table(7,false)
   for x in [-40,-8,24]:tile(RPG,Vector2i(28 if kind == "workbench" else 25,7),Vector2(x,-39))
  "bookcase":furniture_shelf()
  "bread_rack","kitchen_shelf":
   furniture_shelf(false)
   for x in [-24,0,24]:
    for y in [-47,-29,-12]:tile(RPG,Vector2i(55,13) if kind == "bread_rack" else Vector2i(56,16),Vector2(x,y))
  "oven":tile(INDOOR,Vector2i(14,14),Vector2(-24,-48),3)
  "clock":
   tile(RPG,Vector2i(26,8),Vector2(-16,-64),2)
   tile(ONEBIT,Vector2i(19,14),Vector2(-8,-50))
  "flowerpot":tile(INDOOR,Vector2i(16,0),Vector2(-16,-32),2)
  "window":tile(RPG,Vector2i(40,4),Vector2(-16,-32),2)
  "rug":panel(RPG,Vector2i(10,16),Vector2i(9,4),Vector2(-72,-32))
  "banner":patch(RPG,Vector2i(50,3),Vector2i(1,3),Vector2(-8,-48),1,accent.lightened(.3))
  "throne":
   tile(INDOOR,Vector2i(0,6),Vector2(-32,-64),4)
  "fountain":
   panel(RPG,Vector2i(2,0),Vector2i(5,3),Vector2(-40,-32))
   tile(RPG,Vector2i(15,0),Vector2(-16,-64),2)
   tile(RPG,Vector2i(15,0),Vector2(-8,-67),1)
  "castle":castle()
  "pink_door","castle_gate","arch","interior_door":
   var zoom := 1.0 if kind == "interior_door" else 1.5
   patch(DUNGEON,Vector2i(21 if kind in ["arch","interior_door"] else 24,10),Vector2i(3,3),Vector2(-24*zoom,-48*zoom),zoom,Color("#f6bada") if kind != "castle_gate" else Color.WHITE)
  "bridge_rail":tile(RPG,Vector2i(47,24),Vector2(-8,-8))
  "lantern":draw_texture_rect_region(OUTDOOR_LIGHT,Rect2(-8,-80,16,80),Rect2(0,0,16,80))
  "grass_tuft":draw_texture_rect_region(DETAILS,Rect2(-8,-12,16,16),Rect2((absi(variant)%4)*64,128,64,64))
  "stones":tile(RPG,Vector2i(44,10),Vector2(-8,-8))
  "key":tile(ONEBIT,Vector2i(33,11),Vector2(-16,-16),2,Color("#f58fc7"))
  "wall","wall_background":
   var size := Vector2i(ceil(footprint.x/16),ceil(footprint.y/16))
   masonry(size,visual_offset,Color("#ffe3ef") if kind == "wall" else Color("#d5d7e0"))
