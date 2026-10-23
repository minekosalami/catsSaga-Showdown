extends RefCounted
## Technical display treatment; never resamples or saves an image asset.
static func apply(sprite: Sprite2D,step := 2.0) -> void:
	if sprite.texture==null:return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://shaders/actor_pixels.gdshader")
	ink.set_shader_parameter("display_size",sprite.texture.get_size()*sprite.scale.abs())
	ink.set_shader_parameter("pixel_size",step)
	sprite.material = ink
