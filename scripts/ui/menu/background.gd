extends ColorRect
## Reuses the existing battle shader, never a generated background image.
var clock := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=ShaderMaterial.new()
	material.shader=preload("res://shaders/surreal_battle.gdshader")
	material.set_shader_parameter("floor_sheet",preload("res://assets/wonderland_human/ninja/tileset_floor.png"))
	material.set_shader_parameter("boss_active",true)
	material.set_shader_parameter("identity",0)
	material.set_shader_parameter("section",.7)
func _process(delta: float) -> void:
	clock+=delta
	var visuals := get_node("/root/VisualSettings")
	material.set_shader_parameter("clock",clock)
	material.set_shader_parameter("motion",visuals.motion*.4)
	material.set_shader_parameter("reduced",1.0 if visuals.reduced else 0.0)
