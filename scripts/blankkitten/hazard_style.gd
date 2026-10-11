extends RefCounted
## Shared render treatments; all dangerous geometry comes from hazards.shapes_at.
const Energy = preload("res://scripts/ui/energy_laser_style.gd")
static func draw_shape(canvas: Node2D, shape: Dictionary, clock: float, alpha: float, reduced: bool) -> void:
	if alpha <= .001: return
	var tint: Color = shape.tint
	if shape.has("circle"):
		# The shader owns the flame envelope; this thin ring identifies its core.
		canvas.draw_arc(shape.circle,shape.radius,0,TAU,80,Color(1,.83,.42,alpha*.8),1,true)
		if shape.warning:
			canvas.draw_arc(shape.circle,shape.radius+6,0,TAU,80,Color(1,.9,.5,alpha),2,true)
		return
	var rect: Rect2 = shape.rect
	if shape.warning:
		var pulse := .65+.25*sin(clock*TAU*3)
		if shape.get("pillar",false):
			var arena: Rect2 = canvas.battle.arena_rect
			var zone := Rect2(rect.position.x,arena.position.y,rect.size.x,arena.size.y)
			canvas.draw_rect(zone,Color(.95,.28,.46,.11*alpha))
			for y in range(int(zone.position.y),int(zone.end.y),22):
				canvas.draw_line(Vector2(zone.position.x,y),Vector2(zone.end.x,minf(zone.end.y,y+15)),Color(1,.4,.55,.22*alpha),1,true)
			canvas.draw_rect(Rect2(rect.position.x,arena.end.y-9,rect.size.x,8),Color(1,.31,.52,pulse*alpha))
			canvas.draw_rect(zone,Color(1,.72,.82,.7*alpha),false,1,true)
			# High-contrast downward chevrons and an overhead rail, exact lane width.
			var x := zone.get_center().x
			for y in [zone.position.y+15,zone.end.y-28]:
				canvas.draw_polyline(PackedVector2Array([Vector2(x-8,y),Vector2(x,y+7),Vector2(x+8,y)]),Color(1,1,1,pulse*alpha),2,true)
		else:
			canvas.draw_rect(rect,Color(tint,.12*alpha))
			canvas.draw_rect(rect,Color(tint.lightened(.4),pulse*alpha),false,1.5,true)
			var vertical := rect.size.x < rect.size.y
			var begin := Vector2(rect.get_center().x,rect.position.y) if vertical else Vector2(rect.position.x,rect.get_center().y)
			var end := Vector2(begin.x,rect.end.y) if vertical else Vector2(rect.end.x,begin.y)
			canvas.draw_dashed_line(begin,end,Color(1,1,1,.65*alpha),1,9,true,true)
		return
	if shape.get("wall",false):
		# The opaque orange band exactly covers the contact-damage boundary.
		canvas.draw_rect(rect,Color(.85,.18,.025,alpha))
		var horizontal := rect.size.x > rect.size.y
		var length := rect.size.x if horizontal else rect.size.y
		for i in int(length/9):
			var p := rect.position+Vector2(i*9,rect.size.y*.5) if horizontal else rect.position+Vector2(rect.size.x*.5,i*9)
			var flare := 3+3*sin(clock*7+i*1.7)
			canvas.draw_circle(p,flare,Color(1,.55,.12,.65*alpha))
		canvas.draw_rect(rect,Color(1,.8,.35,.85*alpha),false,1,true)
	elif shape.get("laser",false):
		var vertical := rect.size.y > rect.size.x
		canvas.draw_set_transform(rect.get_center(),PI/2 if vertical else 0)
		Energy.draw_beam(canvas,rect.size.y if vertical else rect.size.x,rect.size.x if vertical else rect.size.y,tint,clock,.7,.35 if reduced else .8,alpha)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		# Beveled obsidian slabs / paired corrupted gates, with stable seam texture.
		canvas.draw_rect(rect,Color(.085,.075,.11,alpha))
		canvas.draw_rect(rect.grow(-2),Color(.16,.13,.18,alpha),false,3,true)
		canvas.draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color(.72,.68,.76,alpha),2,true)
		canvas.draw_line(rect.position,rect.position+Vector2(0,rect.size.y),Color(.55,.48,.6,alpha),2,true)
		for y in range(int(rect.position.y)+12,int(rect.end.y)-2,18):
			var seed := sin(y*.31+rect.position.x*.19)
			canvas.draw_rect(Rect2(rect.position.x+4,y,maxf(1,rect.size.x-8),8),Color(.2+seed*.04,.17,.21,alpha*.9))
			var x := rect.position.x+rect.size.x*(.4+.16*seed)
			canvas.draw_polyline(PackedVector2Array([Vector2(x,y-7),Vector2(x+4,y),Vector2(x-2,y+7)]),Color(.85,.31,.4,.4*alpha),1,true)
		if shape.get("paired",false):
			canvas.draw_rect(rect,Color(tint,alpha),false,2,true)
			canvas.draw_line(rect.position+Vector2(3,0),rect.position+Vector2(3,rect.size.y),Color(1,.8,.5,.8*alpha),1,true)
		else:
			canvas.draw_rect(Rect2(rect.position.x,rect.end.y-5,rect.size.x,5),Color(1,.42,.57,.8*alpha))
		if not reduced:
			canvas.draw_rect(rect.grow(4),Color(tint,.12*alpha),false,3,true)

static func intersections(canvas: Node2D, shapes: Array, clock: float, reduced: bool) -> void:
	for a in shapes:
		if a.warning or a.get("axis",-1) != 0: continue
		for b in shapes:
			if b.warning or b.get("axis",-1) != 1 or not a.rect.intersects(b.rect): continue
			var point: Vector2 = a.rect.intersection(b.rect).get_center()
			canvas.draw_circle(point,14,Color(.9,.65,1,.14))
			canvas.draw_circle(point,4,Color.WHITE)
			for i in (4 if reduced else 8):
				var direction := Vector2.RIGHT.rotated(i*TAU/8+clock*2)
				canvas.draw_line(point+direction*7,point+direction*(11+4*sin(clock*11+i)),Color(1,.7,.85,.6),1,true)
