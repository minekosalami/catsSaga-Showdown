extends Node2D
const POINT := Vector2(2660,1100)
var interaction_radius := 145.0
func _ready() -> void:
	add_to_group("interactables")
	set_meta("interaction_offset",Vector2(-16,-76))
	var coin := Sprite2D.new()
	coin.name="GiantNeCoin"
	coin.texture=preload("res://scripts/story/assets.gd").coin()
	coin.scale=Vector2.ONE*6
	coin.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(coin)
	# Unmodified Kenney atlas arrow. Tint/transform only, no invented brush art.
	var arrow := AtlasTexture.new()
	arrow.atlas=preload("res://assets/wonderland_human/onebit/monochrome_transparent_packed.png")
	arrow.region=Rect2(384,192,16,16)
	for i in 5:
		var sprite := Sprite2D.new()
		sprite.name="RedArrow%d"%i
		sprite.texture=arrow
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var angle:float=deg_to_rad([-90,-155,-25,0,150][i])
		sprite.position=Vector2.from_angle(angle)*(240 if i==3 else (205 if i==4 else 140+i%2*22))
		sprite.rotation=angle-PI*.5
		sprite.scale=Vector2.ONE*(3.5+i*.25)
		sprite.modulate=Color("#ff3939")
		add_child(sprite)
func can_interact() -> bool:
	return Session.story_flags.get("boss2_defeated",false) and not Session.story_flags.get("wonderland_arrived",false) and not Session.story_sequence_active
func handle_interaction(world: Node) -> bool:
	if not can_interact():return false
	var sequence=load("res://scripts/story/ambush.gd").new()
	Session.add_child(sequence)
	sequence.start(world)
	return true
