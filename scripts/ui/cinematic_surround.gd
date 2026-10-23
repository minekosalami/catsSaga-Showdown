extends ColorRect
# Responsive outer mat. The internal arena/container transform stays unchanged.
const FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
var age := 0.0
var look: Resource
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _process(delta: float) -> void:
	age += delta
	var battle: Node = get_parent().battle
	if is_instance_valid(battle):
		look = battle.get_node("CinematicArena").look
	queue_redraw()
func _draw() -> void:
	if look == null:
		return
	var host := get_parent()
	var left: float = host.arena_container.position.x
	var right: float = left+540*host.arena_container.scale.x
	if left < 150:
		return
	var tint := Color(look.accent,0.09)
	for side in [0,1]:
		var center := Vector2(left*0.5 if side == 0 else (right+size.x)*0.5,size.y*0.48)
		var radius := minf(left*0.35,132)
		for ring in range(3):
			draw_arc(center,radius+ring*24,age*0.02+ring,age*0.02+ring+PI*1.6,64,Color(tint,0.035),1,true)
		var heading: String = "catsSaga()" if side == 0 else look.boss_name.to_upper()
		var width := FONT.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(FONT,center+Vector2(-width*0.5,-8),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#9598A5"))

	for edge in [left-7,right+7]:
		draw_line(Vector2(edge,18),Vector2(edge,size.y-18),Color(look.accent,0.24),1,true)
