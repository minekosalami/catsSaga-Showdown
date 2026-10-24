extends RefCounted
const RPG = preload("res://assets/wonderland_human/rpg/roguelikeSheet_transparent.png")
static func tile(cell: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas=RPG
	atlas.region=Rect2(Vector2(cell*17),Vector2(16,16))
	return atlas
static func coin() -> AtlasTexture: return tile(Vector2i(53,30))
