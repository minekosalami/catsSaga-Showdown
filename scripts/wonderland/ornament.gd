@tool
extends Node2D
## Original pixel-grid ornaments supplement the repository's 16px environment art.
## Local units are pixels; the shared scene displays them at an integer 2× scale.
@export var kind := "flowers":
	set(value):
		kind = value
		queue_redraw()
@export var accent := Color("#ee79af"):
	set(value):
		accent = value
		queue_redraw()
@export var variant := 0:
	set(value):
		variant = value
		queue_redraw()
const INK := Color("#334451")
const WOOD := Color("#a86d59")
const CREAM := Color("#fff0c9")
const FLOWERS = preload("res://assets/enironment/wonderland/The Fan-tasy Tileset (Free) 1.5.7/The Fan-tasy Tileset (Free)/Art/Props/Animation/Flowers_White.png")
var clock := 0.0
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("wonderland_ornaments")
func tick(time: float) -> void:
	clock = time
	queue_redraw()
func box(r: Rect2,c: Color, border := true) -> void:
	draw_rect(r,c)
	if border and r.size.x>25 and r.size.y>12 and c.r>c.b*1.35 and c.r>c.g*1.1:
		for y in range(int(r.position.y)+4,int(r.end.y)-2,6):
			for x in range(int(r.position.x)+3,int(r.end.x)-5,17): draw_line(Vector2(x,y),Vector2(x+7,y),c.darkened(.09),1)
	if border: draw_rect(r,INK,false,1)
func oval(p: Vector2,r: Vector2,c: Color) -> void:
	# Stepped scanlines give all custom details the same crisp pixel grid.
	for y in range(-int(r.y),int(r.y)+1):
		var width := floorf(r.x*sqrt(maxf(0,1-pow(float(y)/maxf(r.y,1),2))))
		draw_rect(Rect2(p+Vector2(-width,y),Vector2(width*2+1,1)),c)
func flower(p: Vector2,c: Color, size := 2.0) -> void:
	draw_line(p+Vector2(0,2),p+Vector2(0,8),Color("#397457"),1)
	for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: oval(p+d*size,Vector2.ONE*size,c)
	box(Rect2(p-Vector2.ONE,Vector2.ONE*2),Color("#ffe9a0"),false)
func arch(p: Vector2,width: float,height: float,c: Color) -> void:
	box(Rect2(p+Vector2(-width*.5,-height+width*.25),Vector2(width,height-width*.25)),c,false)
	oval(p+Vector2(0,-height+width*.25),Vector2(width*.5,width*.25),c)
func window(p: Vector2,c := Color("#80d8d4")) -> void:
	arch(p,14,21,INK)
	arch(p+Vector2(0,-2),10,17,c)
	draw_line(p+Vector2(0,-19),p-Vector2(0,3),CREAM,1)
	draw_line(p+Vector2(-5,-10),p+Vector2(5,-10),CREAM,1)
func roof(points: PackedVector2Array,c: Color) -> void:
	draw_colored_polygon(points,c)
	draw_polyline(points+PackedVector2Array([points[0]]),INK,2)
func crown(p: Vector2) -> void:
	roof(PackedVector2Array([p+Vector2(-10,0),p+Vector2(-12,-10),p+Vector2(-5,-6),p+Vector2(0,-15),p+Vector2(5,-6),p+Vector2(12,-10),p+Vector2(10,0)]),Color("#f4c76e"))
	box(Rect2(p+Vector2(-10,-2),Vector2(20,4)),Color("#fff0a8"))
func _draw() -> void:
	match kind:
		"window":
			var width := 14.0 if variant == 1 else 20.0
			box(Rect2(-width,-37,width*2,34),accent.darkened(.15))
			box(Rect2(-width+3,-35,width*2-6,30),Color("#fff2d1"))
			if variant == 1: window(Vector2(0,-5),Color("#9cd9da"))
			else:
				for x in [-8,8]: window(Vector2(x,-5),Color("#9cd9da"))
			box(Rect2(-width-3,-4,width*2+6,5),WOOD)
		"interior_door":
			arch(Vector2.ZERO,46,52,INK)
			arch(Vector2(0,-2),42,48,accent)
			arch(Vector2(0,-3),32,43,Color("#33726f"))
			box(Rect2(-24,-54,48,3),CREAM)
		"flowerpot":
			roof(PackedVector2Array([Vector2(-9,-14),Vector2(9,-14),Vector2(6,0),Vector2(-6,0)]),Color("#ce9295"))
			box(Rect2(-11,-16,22,4),Color("#ecb4a8"))
			for i in range(5): flower(Vector2((i-2)*5,-23-(i%2)*6),accent.lightened((i%2)*.15),3)
		"bread_rack","kitchen_shelf":
			box(Rect2(-30,-61,60,62),WOOD)
			for y in [-52,-35,-18]:
				box(Rect2(-26,y,52,13),INK)
				for x in [-17,0,17]:
					if kind == "bread_rack":
						oval(Vector2(x,y+7),Vector2(7,4),Color("#e9b46b"))
						for dx in [-3,1]: draw_line(Vector2(x+dx,y+5),Vector2(x+dx+2,y+8),CREAM,1)
					else:
						box(Rect2(x-5,y+3,9,7),accent)
						box(Rect2(x+4,y+4,3,4),CREAM)
		"workbench","writing_desk":
			box(Rect2(-55,-24,110,26),WOOD)
			box(Rect2(-59,-30,118,10),WOOD.lightened(.2))
			if kind == "writing_desk":
				for i in range(3):
					box(Rect2(-25+i*4,-47+i*3,32,17),CREAM)
					for y in range(-43,-30,4): draw_line(Vector2(-18+i*4,y+i*3),Vector2(0+i*4,y+i*3),Color("#9e7e81"),1)
				box(Rect2(29,-41,9,11),Color("#547984"))
				draw_line(Vector2(32,-41),Vector2(42,-57),CREAM,3)
			else:
				for x in [-37,-13,18]:
					oval(Vector2(x,-36),Vector2(8,8),Color("#f0cc8a"))
					oval(Vector2(x,-36),Vector2(5,5),WOOD)
					oval(Vector2(x,-36),Vector2(2,2),CREAM)
				draw_line(Vector2(35,-40),Vector2(43,-28),Color("#729aaf"),3)
		"flowers","roses":
			# Keep the complete 32px cluster intact. Native animated art replaces
			# hundreds of tiny drawing commands and gives planting richer detail.
			var frame := (int(clock/.15)+int(abs(global_position.x)*.03))%8
			draw_texture_rect_region(FLOWERS,Rect2(-16,-24,32,32),Rect2(frame*96,0,32,32),accent)
		"leaf_litter":
			for i in range(14):
				var p := Vector2((i*17+variant)%71-35,(i*23+variant)%31-15)
				roof(PackedVector2Array([p,p+Vector2(3,-2),p+Vector2(6,0),p+Vector2(3,2)]),accent.lightened((i%3)*.1))
		"giant_flower":
			draw_polyline(PackedVector2Array([Vector2.ZERO,Vector2(-3,-16),Vector2(2,-35),Vector2(0,-47)]),Color("#45816e"),4)
			for side in [-1,1]: roof(PackedVector2Array([Vector2(0,-19),Vector2(side*17,-34),Vector2(side*18,-24)]),Color("#6eaa7e"))
			flower(Vector2(0,-51),accent,7)
		"mushroom":
			mushroom()
		"great_tree":
			oval(Vector2(0,0),Vector2(74,18),Color(.10,.23,.26,.18))
			var bark := Color("#ad895c")
			for side in [-1,1]:
				var r := PackedVector2Array()
				for p in [Vector2(10,-32),Vector2(26,-24),Vector2(39,-12),Vector2(57,-6),Vector2(69,-2),Vector2(70,2),Vector2(53,3),Vector2(36,-3),Vector2(22,-10),Vector2(9,-13)]: r.append(Vector2(p.x*side,p.y))
				roof(r,bark.darkened(.20))
				var curve := PackedVector2Array()
				for p in [Vector2(17,-24),Vector2(30,-16),Vector2(43,-7),Vector2(61,0)]: curve.append(Vector2(p.x*side,p.y))
				draw_polyline(curve,bark.lightened(.12),2)
			roof(PackedVector2Array([Vector2(-23,1),Vector2(-28,-10),Vector2(-26,-28),Vector2(-24,-51),Vector2(-12,-77),Vector2(-4,-101),Vector2(-9,-124),Vector2(-18,-151),Vector2(18,-156),Vector2(20,-135),Vector2(26,-108),Vector2(23,-88),Vector2(13,-62),Vector2(16,-38),Vector2(23,-18),Vector2(29,0)]),bark)
			for x in [-14,-3,10]: draw_polyline(PackedVector2Array([Vector2(x,0),Vector2(x-3,-17),Vector2(x-6,-43),Vector2(x-3,-64),Vector2(x+5,-94),Vector2(x+4,-113),Vector2(x,-145)]),Color("#d0ae76"),2)
			for y in range(-139,-8,9):
				var x := sin(y*.057)*15
				draw_line(Vector2(x,y),Vector2(x+4,y-5),bark.darkened(.18),1)
			oval(Vector2(-9,-54),Vector2(8,14),INK)
			oval(Vector2(-8,-54),Vector2(4,10),WOOD.darkened(.3))
			for side in [-1,1]:
				var vine := PackedVector2Array()
				for y in range(-135,-5,5): vine.append(Vector2(side*18+sin(y*.08)*7,y))
				draw_polyline(vine,Color("#527f6f"),2)
				for y in [-115,-81,-28]: flower(Vector2(side*18+sin(y*.08)*7,y),Color("#e797be"),3)
			for i in range(7):
				var p := Vector2((i%3-1)*42,-143-(i/3)*27)
				oval(p,Vector2(47,31),accent.darkened(.4))
				oval(p+Vector2(-3,-6),Vector2(44,26),accent)
				oval(p+Vector2(-13,-13),Vector2(22,10),accent.lightened(.23))
				for j in range(7): box(Rect2(p+Vector2((j*17)%67-30,(j*11)%29-17),Vector2(5,2)),accent.lightened(.13),false)
		"tea_table","banquet_table":
			var wide := 63.0 if kind == "tea_table" else 100.0
			box(Rect2(-wide+8,-7,8,13),WOOD)
			box(Rect2(wide-16,-7,8,13),WOOD)
			box(Rect2(-wide,-35,wide*2,32),WOOD)
			box(Rect2(-wide+2,-36,wide*2-4,25),CREAM)
			for i in range(-2,3):
				oval(Vector2(i*wide/3.0,-22),Vector2(8,4),Color("#b5dedd"))
				oval(Vector2(i*wide/3.0,-23),Vector2(5,2),CREAM)
				box(Rect2(i*wide/3.0+7,-31,5,5),accent)
				box(Rect2(i*wide/3.0+12,-30,2,3),CREAM)
			oval(Vector2(0,-29),Vector2(7,5),accent)
			box(Rect2(-3,-37,6,5),accent)
			flower(Vector2(1,-42),accent,3)
		"chair":
			box(Rect2(-9,-22,18,20),WOOD)
			box(Rect2(-6,-20,12,10),accent)
			box(Rect2(-10,-7,20,8),accent.lightened(.2))
			for x in [-8,6]: box(Rect2(x,0,3,7),WOOD)
		"teapot","teapot_house","grand_teapot","grand_teacup":
			var f := .55 if kind == "teapot" else 2.0
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE*f)
			var handle := PackedVector2Array()
			for i in range(25): handle.append((Vector2(37,-40)+Vector2.RIGHT.rotated(i*TAU/24)*Vector2(15,21)).round())
			draw_polyline(handle,INK,9,false)
			draw_polyline(handle,accent,5,false)
			if kind != "grand_teacup": roof(PackedVector2Array([Vector2(-24,-30),Vector2(-52,-53),Vector2(-59,-70),Vector2(-47,-70),Vector2(-39,-55),Vector2(-18,-47)]),accent.darkened(.1))
			oval(Vector2(0,-30),Vector2(35,30),INK)
			oval(Vector2(0,-31),Vector2(33,28),accent)
			oval(Vector2(-8,-38),Vector2(23,18),accent.lightened(.2))
			oval(Vector2(0,-59),Vector2(25,6),CREAM)
			if kind == "grand_teacup": oval(Vector2(0,-59),Vector2(22,4),Color("#b97769"))
			else: box(Rect2(-4,-70,8,8),accent)
			for x in [-20,18]: flower(Vector2(x,-32),Color("#fff0b9"),3)
			if kind == "teapot_house":
				arch(Vector2.ZERO,14,24,INK)
				arch(Vector2(0,-1),10,20,Color("#b46a6d"))
				window(Vector2(-19,-30))
			draw_set_transform(Vector2.ZERO)
		"pink_house","clock_house":
			box(Rect2(-42,-67,84,67),Color("#fae0c1"))
			for y in range(-60,-5,7): draw_line(Vector2(-40,y),Vector2(40,y),Color("#e7bba7"),1)
			roof(PackedVector2Array([Vector2(-51,-62),Vector2(-12,-119),Vector2(15,-111),Vector2(50,-62)]),accent)
			for y in range(-96,-62,6): draw_line(Vector2(-22-(y+96)*.55,y),Vector2(23+(y+96)*.55,y),accent.darkened(.18),1)
			for x in [-25,25]: window(Vector2(x,-21))
			arch(Vector2.ZERO,19,32,INK)
			arch(Vector2(0,-1),15,28,accent.darkened(.2))
			box(Rect2(4,-14,2,2),CREAM,false)
			box(Rect2(23,-105,13,26),Color("#c98489"))
			if kind == "clock_house":
				oval(Vector2(0,-77),Vector2(17,18),INK)
				oval(Vector2(0,-77),Vector2(15,16),CREAM)
				for a in range(12): box(Rect2(Vector2(0,-77)+Vector2.UP.rotated(a*TAU/12)*12,Vector2.ONE*2),WOOD,false)
				draw_line(Vector2(0,-77),Vector2(0,-77)+Vector2.UP.rotated(clock*.03)*9,INK,2)
				draw_line(Vector2(0,-77),Vector2(0,-77)+Vector2.UP.rotated(clock*.15)*12,INK,1)
			else: flower(Vector2(0,-81),accent.lightened(.35),6)
		"fountain":
			oval(Vector2(0,0),Vector2(56,28),INK)
			oval(Vector2(0,-3),Vector2(54,26),Color("#d9cbf2"))
			oval(Vector2(0,-5),Vector2(46,20),Color("#62cbd9"))
			for i in range(4): draw_arc(Vector2(0,-5),14+i*7+fmod(clock*5,7),0,TAU,24,Color("#b9f6e5"),1,false)
			box(Rect2(-7,-48,14,43),Color("#cfb7e7"))
			oval(Vector2(0,-48),Vector2(25,10),Color("#ead6f3"))
			oval(Vector2(0,-50),Vector2(21,7),Color("#5abacb"))
			for i in range(-2,3): draw_line(Vector2(i*9,-47),Vector2(i*9,-14+sin(clock*2+i)*3),Color("#b7f1e7"),2)
			crown(Vector2(0,-54))
		"arch","pink_door","castle_gate":
			var locked := kind != "arch"
			arch(Vector2.ZERO,76,96,INK)
			arch(Vector2(0,-2),70,91,accent)
			arch(Vector2(0,-4),53,79,Color("#ffe9ae"))
			arch(Vector2(0,-4),47,74,accent.darkened(.3) if locked else Color("#326e68"))
			if locked:
				for x in range(-17,18,7): draw_line(Vector2(x,-7),Vector2(x,-64),accent.lightened(.2),2)
				draw_line(Vector2(0,-76),Vector2(0,-6),INK,1)
				box(Rect2(-5,-41,10,11),Color("#f6d074"))
				oval(Vector2(0,-37),Vector2(2,2),INK)
			for x in [-38,38]:
				box(Rect2(x-4,-73,8,74),Color("#e5b8d8"))
				for y in range(-66,-3,11): flower(Vector2(x,y),accent.lightened(.15),3)
			crown(Vector2(0,-91))
		"castle": _castle()
		"bookcase":
			box(Rect2(-29,-58,58,58),WOOD.darkened(.12))
			for y in [-52,-36,-20]:
				box(Rect2(-25,y,50,13),INK)
				for i in range(10):
					var c: Color = [accent,Color("#70bdc5"),Color("#efb16e"),Color("#9c8bcd")][(i+variant)%4]
					box(Rect2(-23+i*5,y+2,4,10-(i%3)),c,false)
					box(Rect2(-22+i*5,y+4,2,1),CREAM,false)
		"bed":
			box(Rect2(-25,-60,50,61),WOOD)
			box(Rect2(-22,-58,44,57),CREAM)
			box(Rect2(-20,-36,40,34),accent)
			box(Rect2(-17,-53,34,13),Color("#fff9df"))
			for i in range(-2,3): draw_line(Vector2(i*7,-35),Vector2(i*7,-4),accent.lightened(.2),1)
		"oven":
			box(Rect2(-28,-51,56,53),Color("#c88c82"))
			for y in range(-48,-4,9):
				for x in range(-25,25,12): box(Rect2(x+(y%2)*4,y,10,7),Color("#dfa394"))
			arch(Vector2(0,-3),36,32,INK)
			oval(Vector2(0,-11),Vector2(13,4),Color("#f8c774"))
			for i in range(3): oval(Vector2(-8+i*8,-13),Vector2(3,2),CREAM)
		"counter":
			box(Rect2(-46,-25,92,28),WOOD)
			box(Rect2(-49,-30,98,10),CREAM)
			for x in [-32,-10,12,34]: box(Rect2(x-7,-17,14,14),WOOD.lightened(.12))
			for i in range(4):
				if variant == 1: oval(Vector2(-33+i*22,-33),Vector2(7,4),Color("#e9b46c"))
				elif variant == 2: flower(Vector2(-33+i*22,-43),accent,4)
				else:
					box(Rect2(-39+i*23,-44,15,12),accent.lightened((i%2)*.2))
					box(Rect2(-33+i*23,-44,3,12),CREAM,false)
		"clock":
			box(Rect2(-14,-65,28,66),WOOD)
			oval(Vector2(0,-48),Vector2(12,12),CREAM)
			draw_line(Vector2(0,-48),Vector2(0,-48)+Vector2.UP.rotated(clock*.1+variant)*9,INK,1)
			box(Rect2(-9,-31,18,26),INK)
			var pendulum := sin(clock*1.8+variant)*5
			draw_line(Vector2(0,-30),Vector2(pendulum,-12),Color("#e8be77"),1)
			oval(Vector2(pendulum,-12),Vector2(4,5),Color("#e8be77"))
		"throne":
			box(Rect2(-32,-7,64,12),Color("#d7b790"))
			box(Rect2(-25,-17,50,12),Color("#f4d69a"))
			arch(Vector2(0,-18),40,65,Color("#f4cc76"))
			arch(Vector2(0,-23),30,51,accent)
			for x in [-24,20]: box(Rect2(x,-39,5,24),Color("#ffe4a0"))
			crown(Vector2(0,-80))
		"rug":
			box(Rect2(-70,-35,140,70),accent.darkened(.2))
			box(Rect2(-66,-31,132,62),CREAM)
			box(Rect2(-63,-28,126,56),accent)
			for x in range(-56,60,14):
				for y in [-21,21]: roof(PackedVector2Array([Vector2(x,y-3),Vector2(x+3,y),Vector2(x,y+3),Vector2(x-3,y)]),accent.lightened(.28))
		"banner":
			box(Rect2(-1,-68,2,73),WOOD,false)
			box(Rect2(-6,2,12,3),WOOD)
			box(Rect2(-18,-65,36,4),Color("#e9c88a"))
			roof(PackedVector2Array([Vector2(-14,-61),Vector2(14,-61),Vector2(14,-12),Vector2(0,-3),Vector2(-14,-12)]),accent)
			crown(Vector2(0,-31))
		"key":
			oval(Vector2(-8,-10),Vector2(8,8),INK)
			oval(Vector2(-8,-11),Vector2(6,6),accent)
			oval(Vector2(-8,-11),Vector2(3,3),Color("#ffe9ae"))
			box(Rect2(-4,-8,25,5),accent)
			for x in [11,18]: box(Rect2(x,-5,4,6),accent)
			box(Rect2(-3,-8,23,1),CREAM,false)
func mushroom() -> void:
	# Three authored native-pixel sizes keep density and aspect coherent at 2×.
	var size := absi(variant)%3
	var cap := Vector2([38,25,17][size],[21,14,10][size])
	var stem: float = [37,25,18][size]
	var width: float = [9,6,4][size]
	oval(Vector2(0,1),Vector2(cap.x*.85,cap.y*.42),Color(.10,.19,.23,.17))
	roof(PackedVector2Array([Vector2(-width,0),Vector2(-width*.65,-stem),Vector2(width*.65,-stem),Vector2(width+2,0)]),CREAM.darkened(.12))
	draw_line(Vector2(-1,-stem+4),Vector2(1,-1),CREAM,2)
	draw_set_transform(Vector2(0,roundf(sin(clock*.6+global_position.x*.004))))
	oval(Vector2(0,-stem+2),Vector2(cap.x-1,roundf(cap.y*.52)),INK)
	var center := Vector2(0,-stem-roundf(cap.y*.33))
	oval(center,cap,accent.darkened(.2))
	oval(center+Vector2(-2,-3),cap-Vector2(4,3),accent)
	for p in [Vector2(-.58,-.18),Vector2(-.16,-.65),Vector2(.40,-.47),Vector2(.61,.15),Vector2(-.13,.2)]:
		var spot: Vector2 = (center+p*cap).round()
		oval(spot,Vector2(maxf(2,roundf(cap.x*.13)),maxf(1,roundf(cap.y*.14))),CREAM)
	for i in range(-4,5): draw_line(Vector2(i*width/3,-stem+1),Vector2(i*cap.x*.18,-stem+4),Color("#a17b89"),1)
	draw_set_transform(Vector2.ZERO)

func _castle() -> void:
	# A compact south-facing facade; the one real gate is centered at the feet.
	box(Rect2(-185,-24,370,24),Color("#d5b1d2"))
	box(Rect2(-173,-153,346,132),Color("#f5d1dd"))
	for y in range(-145,-25,12):
		for x in range(-166,160,23): box(Rect2(x+(y%2)*8,y,21,10),Color("#ecc2d6"),false)
	for x in [-159,159]:
		box(Rect2(x-28,-185,56,168),Color("#f4c2d7"))
		for y in range(-175,-30,13): draw_line(Vector2(x-26,y),Vector2(x+26,y),Color("#d89bbf"),1)
		roof(PackedVector2Array([Vector2(x-40,-180),Vector2(x,-248),Vector2(x+39,-180)]),Color("#c95996"))
		for y in range(-238,-180,8):
			var width := (y+248)/68.0*38
			draw_line(Vector2(x-width,y),Vector2(x+width,y),Color("#ad4689"),2)
		for y in [-150,-105,-60]: window(Vector2(x,y),Color("#8caad9"))
		box(Rect2(x-1,-277,2,31),Color("#e7be70"))
		roof(PackedVector2Array([Vector2(x+1,-276),Vector2(x+31,-268),Vector2(x+1,-259)]),Color("#ef80ba"))
	box(Rect2(-91,-191,182,172),Color("#ffe2e3"))
	for y in range(-182,-23,10):
		for x in range(-82,77,20):
			var offset := 8 if (y/10)%2 == 0 else 0
			draw_rect(Rect2(x+offset,y,18,8),Color("#f9d8e1"))
	roof(PackedVector2Array([Vector2(-112,-184),Vector2(-14,-259),Vector2(12,-259),Vector2(112,-184)]),Color("#df6da4"))
	for y in range(-238,-185,8): draw_line(Vector2(-25-(y+238)*1.1,y),Vector2(25+(y+238)*1.1,y),Color("#bd4e8c"),2)
	for x in [-119,-60,60,119]:
		window(Vector2(x,-116))
		box(Rect2(x-12,-113,24,5),Color("#ecb66d"))
		for j in [-8,0,8]: flower(Vector2(x+j,-115),Color("#d8659e"),2)
	window(Vector2(0,-176),Color("#88c5d8"))
	oval(Vector2(0,-147),Vector2(17,17),Color("#e4b368"))
	oval(Vector2(0,-147),Vector2(14,14),Color("#617c9c"))
	for i in range(8): oval(Vector2(0,-147)+Vector2.UP.rotated(i*TAU/8)*8,Vector2(3,3),Color("#a5dae0") if i%2 else Color("#efb2d9"))
	oval(Vector2(0,-147),Vector2(4,4),CREAM)
	arch(Vector2.ZERO,62,96,INK)
	arch(Vector2(0,-2),55,90,Color("#d58fb4"))
	crown(Vector2(0,-118))
	for x in [-86,86]:
		box(Rect2(x-5,-100,10,84),Color("#edb7cd"))
		box(Rect2(x-9,-103,18,7),CREAM)
