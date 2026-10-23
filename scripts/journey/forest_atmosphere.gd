extends Node2D
const LEAF = preload("res://assets/overhaul_human/ninja/leaf_00.png")
var leaves: Array[Dictionary] = []
var clock := 0.0
func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_parent().region_id)
	for i in range(34):
		leaves.append({"point":Vector2(rng.randf_range(0,get_parent().map_size.x),rng.randf_range(0,get_parent().map_size.y)),"speed":rng.randf_range(7,15),"phase":rng.randf_range(0,TAU)})
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	var size: Vector2 = get_parent().map_size
	for item in leaves:
		var point: Vector2 = item.point+Vector2(sin(clock*.4+item.phase)*18,clock*item.speed)
		point.y = fposmod(point.y,size.y)
		# Native human leaf from its intact sprite frame; no generated bitmap.
		draw_texture_rect_region(LEAF,Rect2(point,Vector2(12,14)),Rect2(80,108,36,40),Color(1,1,1,.52))
