@tool
extends Sprite2D
## Original credited atlas pixels, with editor-visible regions and transforms.
@export var kind := "tree":
 set(v):kind=v;refresh()
@export var variant := 0:
 set(v):variant=v;refresh()
@export var animate := true
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
  "cabinet":sheet=preload("res://assets/wonderland_human/rebuild/cabinet.png");region=Rect2(variant%4*32,0,32,96)
  "shelf":sheet=preload("res://assets/wonderland_human/rebuild/cabinet.png");region=Rect2(variant%4*32,104,32,64)
  "clock":sheet=preload("res://assets/wonderland_human/rebuild/clock.png");region=Rect2(variant%3*32,0,32,96)
  "fireplace":sheet=preload("res://assets/wonderland_human/rebuild/fireplace.png");region=Rect2(0,0,96,96)
  "bed":sheet=preload("res://assets/wonderland_human/rebuild/beds.png");region=Rect2((variant%8)*64,0,64,96)
  "fence":sheet=preload("res://assets/wonderland_human/rebuild/garden_fence.png");region=Rect2(0,0,96,80)
  "rug":sheet=preload("res://assets/wonderland_human/rebuild/rug.png");region=Rect2(0,(variant%2)*32,160,32)
 var atlas:=AtlasTexture.new();atlas.atlas=sheet;atlas.region=region;texture=atlas
 offset=Vector2(0,-region.size.y*.5)
