extends Node2D
var effects: Node
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/boss2_afterimage.gdshader")
func _draw() -> void:
	if not is_instance_valid(effects):
		return
	for ghost in effects.ghosts:
		var size: Vector2 = ghost.texture.get_size()*ghost.scale
		draw_texture_rect(ghost.texture,Rect2(ghost.position-size/2,size),false,Color(1,1,1,(1-ghost.age/0.24)*0.20))
