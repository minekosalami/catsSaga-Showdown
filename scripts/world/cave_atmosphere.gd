extends Node2D
## A single following light, restrained haze/dust, and region audio supplied by the shared Ambience service.
const Plan = preload("res://scripts/world/cave_layout.gd")
var player: Node2D
var lamp: PointLight2D
var overlay: CanvasLayer
var dust: Node2D
var haze_material: ShaderMaterial
var clock := 0.0
class Dust extends Node2D:
	var clock := 0.0
	func _draw() -> void:
		var dimensions := get_viewport_rect().size
		for i in 26:
			var point := Vector2(fposmod(i*97.0+sin(clock*.12+i)*18,dimensions.x),fposmod(i*137.0-clock*(1+i%3),dimensions.y))
			draw_rect(Rect2(point,Vector2.ONE*2),Color(.75,.8,.88,.04+.04*sin(clock*.4+i)))
func _ready() -> void:
	var darkness := CanvasModulate.new()
	darkness.name = "UndergroundAmbientLight"
	darkness.color = Color(.39,.34,.43)
	add_child(darkness)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,.75),Color(1,1,1,.15),Color(1,1,1,0)])
	gradient.offsets = PackedFloat32Array([0,.4,1])
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(.5,0)
	texture.gradient = gradient
	lamp = PointLight2D.new()
	lamp.texture = texture
	lamp.texture_scale = 4.0
	lamp.energy = .8
	lamp.color = Color(.84,.91,1)
	lamp.shadow_enabled = false
	add_child(lamp)
	overlay = CanvasLayer.new()
	overlay.layer = 0
	add_child(overlay)
	var haze := ColorRect.new()
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(haze)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze_material = ShaderMaterial.new()
	haze_material.shader = preload("res://shaders/cave_haze.gdshader")
	haze.material = haze_material
	dust = Dust.new()
	overlay.add_child(dust)
func _process(delta: float) -> void:
	if player == null: player = get_parent().get_parent().get_node_or_null("Explorer")
	if player != null: lamp.position = player.position
	overlay.visible = get_parent().visible
	clock += delta
	haze_material.set_shader_parameter("clock",clock)
	dust.clock = clock
	dust.queue_redraw()
