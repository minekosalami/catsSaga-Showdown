extends Node2D
## Procedural portal/explosion effects only. No texture artwork is generated.
const NOVA=[preload("res://assets/overhaul_human/ninja/nova_00.png"),preload("res://assets/overhaul_human/ninja/nova_01.png"),preload("res://assets/overhaul_human/ninja/nova_02.png"),preload("res://assets/overhaul_human/ninja/nova_03.png"),preload("res://assets/overhaul_human/ninja/nova_04.png"),preload("res://assets/overhaul_human/ninja/nova_05.png")]
var burst := 0.0
var clock := 0.0
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()
func _draw() -> void:
	if burst>0:
		# Existing Pixel-Boy/Ninja Adventure animation, with a restrained additive impact.
		var extent:=lerpf(190,630,burst)
		draw_texture_rect(NOVA[mini(5,int(burst*7))],Rect2(Vector2.ONE*-extent*.5,Vector2.ONE*extent),false,Color(1,.7,1,1-burst))
		for i in 3:
			draw_arc(Vector2.ZERO,20+burst*(240+i*55),0,TAU,64,Color(1,.65+i*.1,.95,1-burst),8-i*2)
		for i in 24:
			var direction:=Vector2.from_angle(i*TAU/24)
			draw_line(direction*burst*190,direction*burst*330,Color(1,.9,1,1-burst),3)
	else:
		draw_circle(Vector2.ZERO,43,Color(.09,.02,.16,.95))
		for i in 6:
			var point:=Vector2.from_angle(clock*.6+i*TAU/6)*54
			draw_texture_rect(NOVA[int(clock*10+i)%6],Rect2(point-Vector2.ONE*18,Vector2.ONE*36),false,Color(1,.65,1,.65))
		for i in 3:
			draw_arc(Vector2.ZERO,44+i*5,clock*(1+i*.2),clock*(1+i*.2)+TAU*.85,48,Color(1,.5+i*.2,1),3)
