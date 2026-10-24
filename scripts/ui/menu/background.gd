extends ColorRect
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=ShaderMaterial.new();material.shader=preload("res://shaders/ui_aurora.gdshader")
	var ambient:=preload("res://scripts/ui/presentation/ambient.gd").new()
	add_child(ambient);ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:
	var visuals: Node=get_node("/root/VisualSettings")
	material.set_shader_parameter("motion",.15 if visuals.reduced else visuals.motion)
