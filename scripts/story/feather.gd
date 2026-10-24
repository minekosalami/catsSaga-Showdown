extends Area2D
@export var feather_id := ""
@export var tint := Color.WHITE
func _ready() -> void:
	collision_layer=0
	collision_mask=2
	var sprite := Sprite2D.new()
	sprite.texture=preload("res://assets/enironment/collectibles/feather.png")
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*32.0/sprite.texture.get_height()
	sprite.modulate=tint
	add_child(sprite)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=22
	collision.shape=circle
	add_child(collision)
	body_entered.connect(_collect)
	if feather_id in Session.story_progress.feathers: queue_free()
func _collect(body: Node) -> void:
	if not body.is_in_group("overworld_player") or Session.busy:return
	if Session.story_progress.collect_feather(feather_id):
		Session.show_notification("%d/10 feathers collected!"%Session.story_progress.feathers.size(),"FeatherNotification")
		set_deferred("monitoring",false)
		hide()
		queue_free()
