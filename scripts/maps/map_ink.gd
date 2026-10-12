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
		for marker in canvas.region_markers:
			var label_position: Vector2 = canvas.screen_point(marker.point)
			var text := marker_name(marker)
			var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
			var rect := Rect2(label_position-Vector2(width/2+8,14),Vector2(width+16,28))
			if Rect2(Vector2.ZERO,size).intersects(rect):
				draw_style_box(label_style,rect)
				draw_string(FONT,label_position+Vector2(-width/2,6),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#E4B765") if not marker.discovered else Color(0.94,0.95,0.90))
	for marker in canvas.boss_markers:
		var position: Vector2 = canvas.screen_point(marker.point)
		if not Rect2(Vector2.ZERO,size).grow(-6).has_point(position): continue
		if canvas.circular and position.distance_to(size/2) > size.x/2-8: continue
		draw_circle(position,5.5,Color("#101410"))
		draw_circle(position,3.5,marker.get("color",Color("#5DEA87") if marker.defeated else Color("#FF5166")))
		if not canvas.circular and marker.has("label"):
			var text := marker_name(marker)
			var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var origin := Vector2(clampf(position.x+10,8,size.x-width-8),clampf(position.y+5,20,size.y-8))
			draw_style_box(label_style,Rect2(origin-Vector2(4,16),Vector2(width+8,22)))
			draw_string(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,marker.get("color",Color("#D9DED2")))
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

func _get_tooltip(at_position: Vector2) -> String:
	var canvas: Control = get_parent()
	if canvas.circular: return ""
	for marker in canvas.boss_markers + canvas.region_markers:
		var point: Vector2 = canvas.screen_point(marker.point)
		var text := marker_name(marker)
		var is_region: bool = marker in canvas.region_markers
		if not is_region and not Rect2(Vector2.ZERO,size).grow(-6).has_point(point): continue
		var width := FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18 if is_region else 14).x
		var rect := Rect2(point-Vector2(width/2+8,14),Vector2(width+16,28))
		if not is_region:
			var origin := Vector2(clampf(point.x+10,8,size.x-width-8),clampf(point.y+5,20,size.y-8))
			rect = Rect2(origin-Vector2(4,16),Vector2(width+8,22))
		if point.distance_to(at_position) <= 12 or rect.has_point(at_position):
			var coordinates: Vector2 = marker.local_position
			return "%s\n%s\nX: %s | Y: %s" % [text,Layout.region(marker.area).name,str(coordinates.x),str(coordinates.y)]
	return ""
