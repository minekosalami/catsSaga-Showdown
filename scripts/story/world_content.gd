extends RefCounted
## Map-local coordinates. See docs/story-update-status.md for reference registration.
const SHOP_POSITION := Vector2(2590,852)
const CUPID_POSITION := Vector2(3104,1760)
const BUTTERSCOTCH_POSITION := Vector2(2635,906)
const FEATHERS := {
	"entrance":[["entrance_white",Vector2(1296,320),Color.WHITE],["entrance_brown",Vector2(2606,1328),Color("#9b6238")]],
	"deep_forest":[["deep_blue",Vector2(1690,1120),Color("#4584ff")],["deep_purple",Vector2(1586,2164),Color("#a148ef")],["deep_orange",Vector2(4090,2224),Color("#ff861f")]],
	"bart_area":[["fluffy_pink",Vector2(504,968),Color("#ff89bd")],["fluffy_green",Vector2(2110,1320),Color("#66db42")]],
	"flooded_forest":[["flooded_red",Vector2(928,1700),Color("#f23e43")],["flooded_yellow",Vector2(2044,2692),Color("#ffdf35")],["flooded_cyan",Vector2(3252,1310),Color("#40e6e8")]]
}
static func install(world: Node) -> void:
	install_map(world.map,Session.area_id)

static func install_map(map: Node2D, area: String) -> void:
	if area=="entrance":
		friendly(map,"Butterscotch","butterscotch",BUTTERSCOTCH_POSITION,preload("res://assets/npc textures/nart-yellow-npc.png"))
	elif area=="deep_forest":
		friendly(map,"Cupid","cupid",CUPID_POSITION,preload("res://assets/npc textures/nartheart-npc.png"))
		var shop := Node2D.new()
		shop.set_script(preload("res://scripts/story/shop_building.gd"))
		shop.name="PAWnShop"
		shop.position=SHOP_POSITION
		map.get_node("Characters").add_child(shop)
	elif area=="bart_area" and Session.story_flags.get("blankkitten_defeated",false):
		var npc=map.get_node_or_null("Characters/BlankKitten")
		if npc!=null:
			npc.get_parent().remove_child(npc)
			npc.queue_free()
	for item in FEATHERS.get(area,[]):
		var feather=preload("res://scripts/story/feather.gd").new()
		feather.name=item[0]
		feather.feather_id=item[0]
		feather.position=item[1]
		feather.tint=item[2]
		map.add_child(feather)
static func friendly(map: Node2D, title: String, character: String, point: Vector2, art: Texture2D) -> void:
	var npc=preload("res://scripts/story/friendly_npc.gd").new()
	npc.name=title
	npc.character=character
	npc.position=point
	npc.set_meta("interaction_offset",Vector2(-16,-92))
	var sprite:=Sprite2D.new()
	sprite.texture=art
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*70/art.get_height()
	sprite.position.y=-26
	npc.add_child(sprite)
	map.get_node("Characters").add_child(npc)
