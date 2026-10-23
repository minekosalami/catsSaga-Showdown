extends Control

const Layout = preload("res://scripts/maps/world_layout.gd")
const FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
var label_style: StyleBox

func _ready() -> void:
	label_style = preload("res://scripts/ui/sketch_theme.gd").create().get_stylebox("panel","PanelContainer")

func _draw() -> void:
	var canvas: Control = get_parent()
	if canvas.circular:
		draw_arc(size/2,size.x/2-2,0,TAU,96,Color(0.90,0.92,0.87),2.0,true)
		draw_string(FONT,Vector2(size.x/2-4,18),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	else:
		for label in label_layout():
			var marker: Dictionary=label.marker
			var color: Color=Color("#E4B765") if not marker.get("discovered",true) else Color(0.94,0.95,0.90)
			if not label.region:color=marker.get("color",Color("#D9DED2"))
			draw_style_box(label_style,label.rect)
			draw_string(FONT,label.origin,marker_name(marker),HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size,color)
	for marker in canvas.boss_markers:
		var position: Vector2 = canvas.screen_point(marker.point)
		if not Rect2(Vector2.ZERO,size).grow(-6).has_point(position): continue
		if canvas.circular and position.distance_to(size/2) > size.x/2-8: continue
		draw_circle(position,5.5,Color("#101410"))
		draw_circle(position,3.5,marker.get("color",Color("#5DEA87") if marker.defeated else Color("#FF5166")))
	var point: Vector2 = canvas.screen_point(canvas.player_world)
	if not Rect2(Vector2.ZERO,size).grow(-10).has_point(point): return
	var angle: float = canvas.facing.angle()+PI/2
	var polygon := PackedVector2Array()
	for vertex in [Vector2(0,-10),Vector2(-6,7),Vector2(0,4),Vector2(6,7)]: polygon.append(point+vertex.rotated(angle))
	draw_circle(point,12,Color(0.03,0.04,0.03,0.8))
	draw_colored_polygon(polygon,Color(0.97,0.97,0.92))
	draw_polyline(polygon+PackedVector2Array([polygon[0]]),Color(0.15,0.20,0.14),1.0,true)

func marker_name(marker: Dictionary) -> String:
	return str(marker.label) + (" [?]" if not marker.get("discovered",true) else "")

func label_layout() -> Array[Dictionary]:
	# Drawing and tooltip hit testing use these exact rectangles. Keep region
	# names as anchors, then place the existing point labels in nearby free space.
	var result: Array[Dictionary]=[]
	var canvas: Control=get_parent()
	if canvas.circular:return result
	var occupied: Array[Rect2]=[]
	var visible:=Rect2(Vector2.ZERO,size)
	for marker in canvas.region_markers:
		var point: Vector2=canvas.screen_point(marker.point)
		var width:=FONT.get_string_size(marker_name(marker),HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		var rect:=Rect2(point-Vector2(width/2+8,14),Vector2(width+16,28))
		if not visible.intersects(rect):continue
		result.append({"marker":marker,"rect":rect,"origin":rect.position+Vector2(8,20),"font_size":18,"region":true})
		occupied.append(rect)
	var dots: Array[Vector2]=[]
	for marker in canvas.boss_markers:
		var point: Vector2=canvas.screen_point(marker.point)
		if visible.grow(-6).has_point(point):dots.append(point)
	for marker in canvas.boss_markers:
		var point: Vector2=canvas.screen_point(marker.point)
		if not marker.has("label") or not visible.grow(-6).has_point(point):continue
		var width:=FONT.get_string_size(marker_name(marker),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		var rect:=_place_label(point,Vector2(width+8,22),occupied,dots)
		result.append({"marker":marker,"rect":rect,"origin":rect.position+Vector2(4,16),"font_size":14,"region":false})
		occupied.append(rect)
	return result

func _place_label(point: Vector2,dimensions: Vector2,occupied: Array[Rect2],dots: Array[Vector2]) -> Rect2:
	var positions: Array[Vector2]=[
		point+Vector2(6,-11),point-Vector2(dimensions.x+6,11),
		point-Vector2(dimensions.x/2,dimensions.y+10),point+Vector2(-dimensions.x/2,10),
		point+Vector2(8,10),point-Vector2(dimensions.x+8,dimensions.y+10),
		point+Vector2(8,-dimensions.y-10),point+Vector2(-dimensions.x-8,10)]
	for ring in range(1,10):
		for direction in [-1,1]:
			positions.append(point+Vector2(6,-11+direction*ring*28))
			positions.append(point+Vector2(-dimensions.x-6,-11+direction*ring*28))
	var bounds:=Rect2(Vector2.ONE*8,size-Vector2.ONE*16)
	var best:=Rect2(point,dimensions)
	var best_score:=INF
	for position in positions:
		position.x=clampf(position.x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-dimensions.x))
		position.y=clampf(position.y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-dimensions.y))
		var rect:=Rect2(position,dimensions)
		var overlap:=0.0
		for other in occupied:
			if rect.grow(3).intersects(other):overlap+=rect.grow(3).intersection(other).get_area()
		for dot in dots:
			if dot.is_equal_approx(point):continue
			var dot_rect:=Rect2(dot-Vector2.ONE*7,Vector2.ONE*14)
			if rect.intersects(dot_rect):overlap+=rect.intersection(dot_rect).get_area()
		if is_zero_approx(overlap):return rect
		var score:=overlap*1000+rect.get_center().distance_to(point)
		if score<best_score:best_score=score;best=rect
	return best

func _get_tooltip(at_position: Vector2) -> String:
	var canvas: Control = get_parent()
	if canvas.circular: return ""
	for label in label_layout():
		if label.rect.has_point(at_position):return _marker_tooltip(label.marker)
	for marker in canvas.boss_markers + canvas.region_markers:
		var point: Vector2 = canvas.screen_point(marker.point)
		var is_region: bool = marker in canvas.region_markers
		if not is_region and not Rect2(Vector2.ZERO,size).grow(-6).has_point(point): continue
		if point.distance_to(at_position)<=12:return _marker_tooltip(marker)
	return ""

func _marker_tooltip(marker: Dictionary) -> String:
	var coordinates: Vector2=marker.local_position
	return "%s\n%s\nX: %s | Y: %s" % [marker_name(marker),Layout.region(marker.area).name,str(coordinates.x),str(coordinates.y)]
