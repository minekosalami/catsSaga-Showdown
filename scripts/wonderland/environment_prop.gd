@tool
@static_unload
extends Sprite2D
## Original credited atlas pixels, with editor-visible regions and transforms.
@export var kind := "tree":
 set(v):kind=v;refresh()
@export var variant := 0:
 set(v):variant=v;refresh()
@export var animate := true
static var trimmed:Dictionary={}
const TREES=preload("res://assets/wonderland_human/rebuild/trees_spring.png")
const MUSHROOMS=preload("res://assets/environment_human/lpc_revised/mushrooms.png")
const FLOWERS=preload("res://assets/environment_human/lpc_revised/flowers.png")
func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 refresh()
 add_to_group("wonderland_environment_props")
func refresh() -> void:
 var sheet:Texture2D=TREES
 var region:=Rect2(128+(variant%2)*96,16+128*((variant/2)%3),96,96)
 match kind:
  "mushroom":sheet=MUSHROOMS;region=Rect2(96+variant%3*32,(variant/3)%3*32,32,32)
  "flowers":sheet=FLOWERS;region=Rect2((variant%6)*32,32,32,32)
  "cabinet":sheet=preload("res://assets/wonderland_human/rebuild/cabinet.png");region=Rect2(variant%4*32,0,32,80)
  "shelf":sheet=preload("res://assets/wonderland_human/rebuild/cabinet.png");region=Rect2(variant%4*32,96,32,80)
  "clock":sheet=preload("res://assets/wonderland_human/rebuild/clock.png");region=Rect2(variant%3*32,0,32,96)
  "fireplace":sheet=preload("res://assets/wonderland_human/rebuild/fireplace.png");region=Rect2(0,0,96,96)
  "bed":sheet=preload("res://assets/wonderland_human/rebuild/beds.png");region=Rect2((variant%8)*64,0,64,96)
  "fence":sheet=preload("res://assets/wonderland_human/rebuild/garden_fence.png");region=Rect2(0,0,96,80)
  "chair":sheet=preload("res://assets/wonderland_human/cohesion/chair.png");region=Rect2(0,(variant%8)*32,32,32)
  "sofa":sheet=preload("res://assets/wonderland_human/cohesion/sofa.png");region=Rect2((variant%4)*64,0,64,32)
  "worktable":sheet=preload("res://assets/wonderland_human/cohesion/table.png");region=Rect2(0,16+variant%3*64,96,48)
  "vanity":sheet=preload("res://assets/wonderland_human/cohesion/desk.png");region=Rect2(0,0,64,96)
  "shopcounter":sheet=preload("res://assets/wonderland_human/cohesion/counter.png");region=Rect2(64,136,128,56)
  "stove":sheet=preload("res://assets/wonderland_human/cohesion/stove.png");region=Rect2(0,0,32,64)
  "painting":sheet=preload("res://assets/wonderland_human/cohesion/paintings.png");region=Rect2(0,0,64,32)
  "throne":sheet=preload("res://assets/wonderland_human/cohesion/thrones.png");region=Rect2(0,0,32,64)
  "rug":sheet=preload("res://assets/wonderland_human/rebuild/rug.png");region=Rect2(0,(variant%2)*32,160,32)
 var anchor_width:=region.size.x
 if kind not in ["tree","mushroom","flowers"]:
  var key:String=sheet.resource_path+str(region)
  if not trimmed.has(key):trimmed[key]=sheet.get_image().get_region(Rect2i(region)).get_used_rect()
  var used:Rect2=Rect2(trimmed[key]);region=Rect2(region.position+used.position,used.size)
  offset.x=used.position.x+used.size.x*.5-anchor_width*.5
 var atlas:=AtlasTexture.new();atlas.atlas=sheet;atlas.region=region;texture=atlas
 offset.y=-region.size.y*.5
