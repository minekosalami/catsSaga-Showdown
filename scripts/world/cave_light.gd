extends PointLight2D
@export var base_energy := .75
@export var phase := 0.0
var clock := 0.0
func _ready():
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,.8),Color(1,1,1,.28),Color(1,1,1,0)])
	gradient.offsets = PackedFloat32Array([0,.4,1])
	var glow := GradientTexture2D.new()
	glow.width = 192
	glow.height = 192
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5,.5)
	glow.fill_to = Vector2(.5,0)
	glow.gradient = gradient
	texture = glow
	texture_scale = 2.5
	shadow_enabled = false
func _process(delta: float):
	clock += delta
	energy = base_energy*(.96+.025*sin(clock*3.1+phase)+.015*sin(clock*7.7+phase*1.7))
