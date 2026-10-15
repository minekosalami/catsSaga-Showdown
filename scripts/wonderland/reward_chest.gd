extends "res://scripts/world/npc.gd"
const Plan = preload("res://scripts/wonderland/layout.gd")
const Art = preload("res://scripts/world/cave_assets.gd")
var picture: Sprite2D
var key: Node2D
var barrier: Node2D
var closed_texture: Texture2D
var open_texture: Texture2D
func _ready() -> void:
	super._ready()
	interaction_radius = 100
	set_meta("interaction_label","Z  OPEN CHEST")
	picture = Sprite2D.new()
	closed_texture = Art.texture("save_chest")
	open_texture = Art.texture("chest")
	picture.texture = closed_texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.scale = Vector2.ONE*2
	picture.position.y = -24
	picture.modulate = Color("#efabd0")
	add_child(picture)
	var builder := preload("res://scripts/wonderland/builder.gd").new()
	builder.solid(self,Vector2(48,26),Vector2(0,-8))
	key = preload("res://scripts/wonderland/ornament.gd").new()
	key.kind = "key"
	key.accent = Color("#f58fc7")
	key.scale = Vector2.ONE*1.5
	key.position = Vector2(0,-45)
	add_child(key)
	barrier = Node2D.new()
	barrier.position = Vector2(-192,0)
	add_child(barrier)
	builder.solid(barrier,Vector2(32,960))
	for i in range(-7,8):
		var stone := Sprite2D.new()
		stone.texture = Art.texture("boulder")
		stone.position.y = i*64
		stone.scale = Vector2.ONE*2
		barrier.add_child(stone)
	_process(0)
func can_interact() -> bool:
	return Session.story_flags.get("incarna_defeated",false)
func _process(_delta: float) -> void:
	var defeated: bool = Session.story_flags.get("incarna_defeated",false)
	barrier.visible = not defeated
	barrier.get_child(0).get_child(0).set_deferred("disabled",defeated)
	var opened: bool = Session.story_flags.get(Plan.CHEST_OPEN,false)
	picture.texture = open_texture if opened else closed_texture
	key.visible = not opened
	picture.modulate = Color("#b19caa") if opened else Color("#efabd0")
	set_meta("interaction_label","Z  EMPTY CHEST" if opened else "Z  OPEN CHEST")
func handle_interaction(_world: Node) -> bool:
	if not can_interact(): return true
	if not Session.story_flags.get(Plan.CHEST_OPEN,false):
		Session.story_flags[Plan.CHEST_OPEN] = true
		Session.story_flags[Plan.PINK_KEY] = true
		Session.save_current()
		Session.show_notification("Obtained: Pink Wonderland Key","WonderlandKeyNotification")
	else: Session.show_notification("The chest is empty.","WonderlandNotification")
	return true
