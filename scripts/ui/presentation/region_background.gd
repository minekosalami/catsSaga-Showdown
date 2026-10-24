extends Node2D
## Existing human scenery, deliberately dimmed behind the simulation.
const TREE=preload("res://assets/overhaul_human/ninja/tree_round.png")
const LEAF=preload("res://assets/overhaul_human/ninja/leaf_00.png")
const PROFILES={"entrance":Color("#31594b"),"deep_forest":Color("#243f54"),"bart_area":Color("#56405d"),"flooded_forest":Color("#244553")}
var region_id:="entrance"
var clock:=0.0
var scenery: ColorRect
var trees: Array[Vector3]=[]
var motes: Array[Vector3]=[]
func _ready() -> void:
	region_id=Session.forest_encounters.active.get("area",Session.area_id)
	z_index=-20;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	scenery=ColorRect.new();scenery.show_behind_parent=true;scenery.mouse_filter=Control.MOUSE_FILTER_IGNORE;scenery.size=Vector2(540,900)
	scenery.material=ShaderMaterial.new()
	scenery.material.shader=preload("res://shaders/showdown_environment.gdshader")
	scenery.material.set_shader_parameter("grass",preload("res://assets/environment_human/lpc/grass.png"))
	scenery.material.set_shader_parameter("water",preload("res://assets/environment_human/lpc/water.png"))
	scenery.material.set_shader_parameter("atmosphere",PROFILES.get(region_id,PROFILES.entrance))
	scenery.material.set_shader_parameter("flooded",1.0 if region_id=="flooded_forest" else 0.0)
	add_child(scenery);move_child(scenery,0)
	var rng:=RandomNumberGenerator.new();rng.seed=hash(region_id)
	for side in 2:
		for i in 7:trees.append(Vector3(-30 if side==0 else 508,50+i*133+rng.randf_range(-18,18),rng.randf_range(.9,1.35)))
	for i in 20:motes.append(Vector3(rng.randf()*540,rng.randf()*900,rng.randf()*TAU))
func _process(delta: float) -> void:
	var visuals: Node=get_node("/root/VisualSettings")
	clock+=delta*(.15 if visuals.reduced else visuals.motion)
	scenery.material.set_shader_parameter("motion",.1 if visuals.reduced else visuals.motion*.5)
	queue_redraw()
func _draw() -> void:
	for i in trees.size():
		var point:=trees[i]
		var side: float=-1 if i<7 else 1
		var origin:=Vector2(point.x+sin(clock*.3+i)*1.5,point.y)
		draw_texture_rect(TREE,Rect2(origin,Vector2(95,96)*point.z),false,Color(.18,.24,.27,.8))
		if region_id=="flooded_forest":draw_texture_rect(TREE,Rect2(origin+Vector2(15,110),Vector2(65,-50)),false,Color(.1,.17,.24,.25))
	var tint: Color=Color("#e4b3ca") if region_id=="bart_area" else Color("#c6f4b4")
	for i in motes.size():
		var mote:=motes[i]
		var point:=Vector2(fposmod(mote.x+clock*2.8,540),fposmod(mote.y-clock*3.2,900))
		if i%4==0:draw_texture_rect(LEAF,Rect2(point,Vector2(7,7)),false,Color(tint,.12))
		else:draw_circle(point,1,Color(tint,.11))
