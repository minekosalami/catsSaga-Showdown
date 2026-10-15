extends Node2D
## One controller updates visible animated ornaments; no per-prop process loops.
@export var indoor := false
var clock := 0.0
var ornaments: Array[Node] = []
var flowers: Array[Vector2] = []
var accumulator := 0.0
func _ready() -> void:
	for node in get_tree().get_nodes_in_group("wonderland_ornaments"):
		if not get_parent().is_ancestor_of(node): continue
		if node.kind in ["fountain","clock","clock_house","pink_house","teapot","teapot_house","grand_teapot","grand_teacup","mushroom","flowers","roses"]: ornaments.append(node)
		if node.kind in ["flowers","roses"] and flowers.size()<100: flowers.append(node.position)
func _process(delta: float) -> void:
	clock += delta
	accumulator += delta
	if accumulator < .083: return
	accumulator = 0
	var viewport := get_viewport_rect()
	for node in ornaments:
		var screen: Vector2 = get_canvas_transform()*node.global_position
		if viewport.grow(350).has_point(screen): node.tick(clock)
	queue_redraw()
func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	if not indoor:
		for i in range(0,flowers.size(),4):
			var p: Vector2 = flowers[i]+Vector2(sin(clock*.4+i)*29,-22+sin(clock*.8+i)*16)
			if not get_viewport_rect().grow(50).has_point(get_canvas_transform()*p): continue
			var color: Color = [Color("#fff0ab"),Color("#fd88ba"),Color("#b4f5e6")][i%3]
			var width := 2.0+absf(sin(clock*3.5+i))*3
			draw_rect(Rect2(p-Vector2(width,0),Vector2(width*2,2)),color)
			draw_rect(Rect2(p+Vector2(0,-1),Vector2(1,4)),Color("#685674"))
	for node in ornaments:
		if node.kind not in ["teapot","teapot_house","grand_teapot","grand_teacup","clock_house","pink_house"]: continue
		for i in range(3):
			var age := fposmod(clock*.45+i*.33,1)
			var factor := .55 if node.kind == "teapot" else 2.0
			var offset := Vector2(-51,-70)*factor
			if node.kind == "grand_teacup": offset = Vector2(0,-60)*factor
			if node.kind in ["clock_house","pink_house"]: offset = Vector2(29,-107)
			var origin: Vector2 = node.position+offset*node.scale
			draw_arc(origin+Vector2(sin(age*5+i)*7,-age*47),4+age*5,0,PI,8,Color(1,.97,.90,(1-age)*.5),2,false)
