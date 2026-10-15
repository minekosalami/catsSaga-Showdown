extends RefCounted
## Unchanged human source sheets; see docs/wonderland-asset-credits.md.
const RPG = preload("res://assets/wonderland_human/rpg/roguelikeSheet_transparent.png")
static func texture(kind: String) -> AtlasTexture:
 var cell: Vector2i = {"chest_closed":Vector2i(38,0),"chest_open":Vector2i(39,0),"rock":Vector2i(55,21),"grass":Vector2i(5,0),"path":Vector2i(8,22)}[kind]
 var result := AtlasTexture.new()
 result.atlas = RPG
 result.region = Rect2(Vector2(cell*17),Vector2.ONE*16)
 return result
