extends Node2D
# Atlas samples from the existing overworld. No tile collisions, PNG edits, RNG
# calls into the gameplay generator, or frame-time allocation of scene nodes.
const ATLAS = preload("res://assets/enironment/gfx/Overworld.png")
const OBJECTS = preload("res://assets/enironment/gfx/objects.png")
var look: Resource
var stage := 0.0
var clock := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	update_tone()

func update_tone() -> void:
	var ground_tint := Color(0.22,0.27,0.31).lerp(Color(0.045,0.065,0.10),stage)
	if look.angular:
		ground_tint = Color(0.31,0.20,0.27).lerp(Color(0.09,0.035,0.085),stage)
	modulate = ground_tint

func _draw() -> void:
	if look == null:
		return
	# The atlas commands are retained by Godot. Phase grading changes modulate,
	# so hundreds of ground tiles are NOT rebuilt on every rendered frame.
	# A curved forest clearing, or banked flooded path. Every tile is 2x crisp.
	for y in range(29):
		for x in range(17):
			var tile := Vector2i(5,9) if (x*7+y*11)%5 else Vector2i(7,9)
			var center := 8.0+sin(y*0.23)*1.25
			if absf(x-center) < 2.2:
				tile = Vector2i(1,30) if (x+y)%7 else Vector2i(2,32)
			elif look.flooded and (x < 3 or x > 13 or (y > 16 and x > 11)):
				tile = Vector2i(1,1)
			elif (x*3+y*7)%11 == 0:
				tile = Vector2i(17,30)
			draw_texture_rect_region(ATLAS,Rect2(x*32,y*32,32,32),Rect2(Vector2(tile*16),Vector2(16,16)),Color.WHITE)
	# Intact two-cell trees line the arena edge. Mid-field stays free of scenery.
	for side in [0,1]:
		for i in range(7):
			var px := -24.0 if side == 0 else 486.0
			var py := 80.0+i*122.0+(32 if side else 0)
			draw_texture_rect_region(OBJECTS,Rect2(px,py,80,80),Rect2(192,192,32,32),Color(0.7,0.9,1))
