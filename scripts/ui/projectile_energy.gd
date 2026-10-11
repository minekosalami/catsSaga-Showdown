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
	var shared := shared_atlas()
	canvas.draw_texture_rect_region(shared,Rect2(Vector2.ONE*(-radius-3),Vector2.ONE*(radius+3)*2),Rect2(0,128,64,64),tint)
	canvas.draw_texture_rect_region(shared,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),Rect2(0,0,64,64),tint)
	canvas.draw_texture_rect_region(shared,Rect2(Vector2.ONE*-radius*0.64,Vector2.ONE*radius*1.28),Rect2(0,64,64,64),Color(1,1,1,0.94+0.06*sin(clock*4)))
	canvas.draw_arc(Vector2.ZERO,radius-0.5,0,TAU,24,tint.lightened(0.25),1,true)
