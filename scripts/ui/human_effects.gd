extends RefCounted
## Original Pixel-Boy CC0 frames. Atlas crops select transparent padding only;
## source PNGs stay unchanged. Shared frames avoid per-projectile scene nodes.
const ROOT := "res://assets/overhaul_human/ninja/"
static var frames: Dictionary = {}
static func frame(kind: String,index: int) -> Texture2D:
	var count: int = {"flame":12,"nova":6,"sparkle":5,"smoke":6,"leaf":12}[kind]
	var key := kind+str(posmod(index,count))
	if not frames.has(key):
		var texture: Texture2D = load(ROOT+kind+"_%02d.png" % posmod(index,count))
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		# Known frame canvas crops; flame/smoke are already tightly framed.
		atlas.region = Rect2(40,40,48,48) if kind=="nova" and posmod(index,count)==0 else Rect2(Vector2.ZERO,texture.get_size())
		if kind=="nova" and posmod(index,count)>0:
			var sizes := [40,64,88,112,128,128]
			var extent: float = sizes[posmod(index,count)]
			atlas.region = Rect2(Vector2.ONE*(128-extent)*.5,Vector2.ONE*extent)
		frames[key] = atlas
	return frames[key]
static func draw_projectile(canvas: CanvasItem,radius: float,tint: Color,clock: float,style: int = 0) -> void:
	# A dark separation edge and exact-radius rim make dangerous geometry clear.
	canvas.draw_circle(Vector2.ZERO,radius+1.3,Color("#080c19"))
	var art := frame("nova",int(clock*11)%4)
	canvas.draw_texture_rect(art,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),false,tint.lightened(.5))
	if style==2:
		var flame := frame("flame",int(clock*14))
		var size := flame.get_size()*(radius*2.5/flame.get_height())
		canvas.draw_texture_rect(flame,Rect2(Vector2(-size.x*.5,-radius*1.45),size),false,Color(1,1,1,.7))
	elif style in [1,3]:
		canvas.draw_texture_rect(frame("sparkle",int(clock*12)),Rect2(Vector2.ONE*-radius*1.15,Vector2.ONE*radius*2.3),false,tint.lightened(.6))
	canvas.draw_arc(Vector2.ZERO,radius,0,TAU,20,tint.lightened(.5),.9,true)
	canvas.draw_circle(Vector2.ZERO,maxf(1,radius*.26),Color.WHITE)
static func draw_impact(canvas: CanvasItem,point: Vector2,age: float,duration: float,size: float,tint: Color) -> void:
	var p := clampf(age/duration,0,.999)
	var extent := size*(.65+p*.7)
	canvas.draw_texture_rect(frame("nova",int(p*6)),Rect2(point-Vector2.ONE*extent,Vector2.ONE*extent*2),false,Color(tint.lightened(.5),1-p))
	canvas.draw_texture_rect(frame("sparkle",int(p*5)),Rect2(point-Vector2.ONE*extent*.7,Vector2.ONE*extent*1.4),false,Color(1,1,1,1-p))
