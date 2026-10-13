extends RefCounted
## Regions verified against the original sheets; no image duplication or modification.
const PACK := "res://assets/enironment/basic caves and dungeons 32x32 standard - v1.0/basic caves and dungeons 32x32 standard - v1.0/"
const FURNITURE := "res://assets/makeshift_furnitureset.png"
const OBJECTS := PACK+"assets/assets-all.png"
const REGIONS := {
	"armchair":Rect2(0,0,32,64), "chair":Rect2(64,0,32,64), "table":Rect2(224,32,32,32),
	"shelf":Rect2(288,80,96,48), "bed":Rect2(96,160,32,64), "blanket":Rect2(0,224,64,32),
	"supplies":Rect2(128,64,64,32), "books":Rect2(288,64,64,32),
	"torch":Rect2(304,16,32,48), "brazier":Rect2(256,32,48,64),
	"chest":Rect2(164,63,32,30), "save_chest":Rect2(164,32,32,30),
	"spike":Rect2(32,128,64,112), "stalagmite":Rect2(96,112,64,48),
	"rock":Rect2(152,224,40,32), "boulder":Rect2(192,224,40,32), "rock_cluster":Rect2(208,280,48,40),
	"hole":Rect2(176,64,64,48), "pebbles":Rect2(160,384,64,32), "sign":Rect2(400,64,48,32)
}
const INDOOR := ["armchair","chair","table","shelf","bed","blanket","supplies","books"]
static func texture(kind: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/enironment/gfx/cave.png" if kind == "hole" else (FURNITURE if kind in INDOOR else OBJECTS))
	atlas.region = REGIONS[kind]
	return atlas
