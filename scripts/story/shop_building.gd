extends "res://scripts/world/npc.gd"
func _ready() -> void:
	super._ready()
	interaction_radius=120
	var art:=AtlasTexture.new()
	art.atlas=preload("res://assets/enironment/gfx/Overworld.png")
	art.region=Rect2(96,0,80,80)
	var sprite:=Sprite2D.new()
	sprite.texture=art
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2(2,2)
	sprite.position.y=-80
	add_child(sprite)
	var sign:=Label.new()
	sign.text="PAWn Shop"
	sign.position=Vector2(-64,-178)
	sign.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	sign.add_theme_color_override("font_outline_color",Color.BLACK)
	sign.add_theme_constant_override("outline_size",4)
	add_child(sign)
	var body:=StaticBody2D.new()
	body.collision_layer=1
	body.collision_mask=2
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(112,52)
	collision.shape=shape
	collision.position.y=-30
	body.add_child(collision)
	add_child(body)
func handle_interaction(world: Node) -> bool:
	if is_instance_valid(world.story_shop):return true
	world.story_shop=preload("res://scripts/story/shop_screen.gd").new()
	world.story_shop.world=world
	world.add_child(world.story_shop)
	return true
