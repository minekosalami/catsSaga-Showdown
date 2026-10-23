extends RefCounted

# Three cached radial ramps are shared by every projectile, without shaders or
# extra scene nodes. These mathematical UI gradients do not alter any artwork.
static var ramps: Array[GradientTexture2D] = []
static var atlas: ImageTexture
static func texture(kind: int) -> GradientTexture2D:
	if ramps.is_empty():
		for profile in range(3):
			var gradient := Gradient.new()
			if profile == 0: # smoothly shaded colored body
				gradient.offsets = PackedFloat32Array([0,0.25,0.60,0.82,0.96,1])
				gradient.colors = PackedColorArray([Color.WHITE,Color.WHITE,Color(0.6,0.6,0.6),Color(0.85,0.85,0.85),Color(1,1,1,0.9),Color(1,1,1,0)])
			elif profile == 1: # white-hot center
				gradient.offsets = PackedFloat32Array([0,0.2,0.45,0.7,1])
				gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.95),Color(1,1,1,0.65),Color(1,1,1,0.12),Color(1,1,1,0)])
			else: # soft, strictly decorative halo
				gradient.offsets = PackedFloat32Array([0,0.5,0.75,1])
				gradient.colors = PackedColorArray([Color(1,1,1,0.10),Color(1,1,1,0.08),Color(1,1,1,0.035),Color(1,1,1,0)])
			var ramp := GradientTexture2D.new()
			ramp.width = 64
			ramp.height = 64
			ramp.fill = GradientTexture2D.FILL_RADIAL
			ramp.fill_from = Vector2(0.5,0.5)
			ramp.fill_to = Vector2(0.5,0)
			ramp.gradient = gradient
			ramps.append(ramp)
	return ramps[kind]

static func shared_atlas() -> ImageTexture:
	if atlas == null:
		# Packing the mathematical ramps into one shared texture keeps all three
		# layers on the same render batch. No imported/source artwork is involved.
		var image := Image.create(64,192,false,Image.FORMAT_RGBA8)
		for kind in range(3):
			var ramp: Gradient = texture(kind).gradient
			for y in range(64):
				for x in range(64):
					var distance := Vector2(x+0.5-32,y+0.5-32).length()/32.0
					image.set_pixel(x,y+kind*64,ramp.sample(distance) if distance < 1 else Color.TRANSPARENT)
		atlas = ImageTexture.create_from_image(image)
	return atlas

static func draw_orb(canvas: CanvasItem, radius: float, tint: Color, clock: float) -> void:
	var style: int = canvas.visual_style if "visual_style" in canvas else 1
	preload("res://scripts/ui/human_effects.gd").draw_projectile(canvas,radius,tint,clock,style)

static func draw_motion_trail(canvas: CanvasItem, radius: float, tint: Color, direction: Vector2, speed: float) -> void:
	# Low-opacity tail outside the crisp core. No stored positions or nodes.
	var length := clampf((speed-90.0)*0.035,0,12)
	if length <= 0:
		return
	for i in range(3):
		var p := -direction*(radius+1+length*i/3)
		canvas.draw_line(p,p-direction*length/3,Color(tint,0.22-i*0.065),maxf(1,2-i*0.45),true)
