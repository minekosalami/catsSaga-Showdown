extends RefCounted

# Shared mathematical gradients, not image assets or per-beam shader instances.
static var textures: Dictionary = {}
static func gradient(tint: Color, glow: bool = false) -> GradientTexture2D:
	var key := str(tint)+str(glow)
	if textures.has(key):
		return textures[key]
	var ramp := Gradient.new()
	if glow:
		ramp.offsets = PackedFloat32Array([0,0.25,0.5,0.75,1])
		ramp.colors = PackedColorArray([Color(tint,0),Color(tint,0.04),Color(tint,0.22),Color(tint,0.04),Color(tint,0)])
	else:
		ramp.offsets = PackedFloat32Array([0,0.13,0.32,0.46,0.5,0.54,0.68,0.87,1])
		ramp.colors = PackedColorArray([tint.darkened(0.25),tint,tint.lightened(0.35),Color("#FFF4EE"),Color.WHITE,Color("#FFF4EE"),tint.lightened(0.35),tint,tint.darkened(0.25)])
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 64
	texture.fill_from = Vector2(0.5,0)
	texture.fill_to = Vector2(0.5,1)
	texture.gradient = ramp
	textures[key] = texture
	return texture

static func draw_beam(canvas: CanvasItem, length: float, width: float, tint: Color, clock: float, energy: float, glow: float, opacity: float = 1.0, core_width: float = -1.0) -> void:
	canvas.draw_texture_rect(gradient(tint,true),Rect2(-length/2,-width/2-14,length,width+28),false,Color(1,1,1,glow*opacity))
	# The opaque dangerous body always reaches both collider edges immediately.
	# The cross has a thin collider inside a wider, translucent energy envelope.
	canvas.draw_texture_rect(gradient(tint),Rect2(-length/2,-width/2,length,width),false,Color(1,1,1,opacity*(0.30 if core_width > 0 else 1.0)))
	if core_width > 0:
		canvas.draw_rect(Rect2(-length/2,-core_width/2,length,core_width),Color(1,1,1,opacity))
	for side in [-1,1]:
		canvas.draw_line(Vector2(-length/2,side*width/2),Vector2(length/2,side*width/2),Color(tint.lightened(0.3),opacity*(0.25 if core_width > 0 else 1.0)),1,true)
	var flow := PackedVector2Array()
	for i in range(25):
		var x := -length/2+length*float(i)/24
		flow.append(Vector2(x,sin(x*0.055-clock*9)*width*0.18))
	canvas.draw_polyline(flow,Color(1,0.95,0.9,(0.35+0.2*energy)*opacity),1,true)
	for i in range(12):
		var x := -length/2+fposmod(i*length/12+clock*150,length)
		var y := sin(clock*4+i)*width*0.27
		canvas.draw_line(Vector2(x,y),Vector2(x+14,y),Color(1,1,1,0.4*opacity),1.5)
	for i in range(6):
		var p := fposmod(clock*1.4+float(i)/6,1)
		var angle := i*TAU/6+clock
		canvas.draw_line(Vector2.RIGHT.rotated(angle)*width*0.4,Vector2.RIGHT.rotated(angle)*width*(0.4+p),Color(tint.lightened(0.5),(1-p)*0.5*opacity),1,true)
