extends Node
## Artwork-only idle; the NPC's interaction, collision and position are untouched.
var picture: Sprite2D
var rest_scale := Vector2.ONE
var rest_rotation := 0.0
var age := 0.0
func _ready() -> void:
	picture = get_parent().find_child("*Sprite*",true,false) as Sprite2D
	if picture==null:return
	rest_scale = picture.scale
	rest_rotation = picture.rotation
	preload("res://scripts/ui/pixel_art.gd").apply(picture)
	age = fposmod(float(hash(get_parent().name)),6.0)
func _process(delta: float) -> void:
	if picture==null:return
	age += delta
	var breath := sin(age*2)*.012
	picture.scale = rest_scale*Vector2(1-breath*.4,1+breath)
	picture.rotation = rest_rotation+sin(age*.8)*.008
