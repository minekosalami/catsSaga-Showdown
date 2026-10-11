extends Node2D
## Analytic hazards share the soundtrack clock; no spawning timers, physics
## impulses or delayed callbacks can leak across retries or stage changes.
const Cue = preload("res://scripts/blankkitten/timeline.gd")
const BALL_RADIUS := 24.0
var battle: Node
var stage := -1
var phase_start := 0.0
var clock := 0.0
var damaging := false
var pillars: Array[Dictionary] = []
var impacts_seen: Dictionary = {}
var impact_log: Array[float] = []
var debris: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var last_clock := 0.0
var pillar_warning := 0.95
var pillar_fall := 0.16
var floor_hold := 0.22
var retract := 0.24

func _ready() -> void:
	if battle == null:
		battle = get_parent().get_parent()
	process_physics_priority = 0

func configure(next: int) -> void:
	stage = next
	phase_start = Cue.STARTS[stage]
	damaging = stage in [1,2,4,5,6]
	pillars.clear()
	impacts_seen.clear()
	debris.clear()
	last_clock = phase_start
	if stage in [1,6]:
		build_pillars(stage == 6)

func build_pillars(extreme: bool) -> void:
	pillar_warning = 0.68 if extreme else 0.95
	pillar_fall = 0.13 if extreme else 0.16
	var grid := Cue.HALF_MEASURE if extreme else Cue.MEASURE
	var offset: float = battle.cue_sheet.musical_phase_offset
	var first: float = offset + ceil((phase_start + pillar_warning + pillar_fall - offset) / grid)*grid
	var arena: Rect2 = Cue.BOXES[stage]
	var rng := RandomNumberGenerator.new()
	rng.seed = battle.cue_sheet.pattern_seed + stage
	var lane := 2
	var normal_steps := [0,1,2,4,5,6,8,9,10]
	var count := 30 if extreme else 9
	for i in range(count):
		var target: float = first + (i if extreme else normal_steps[i])*grid
		if target + floor_hold + retract >= Cue.STARTS[stage+1]-Cue.MORPH:
			break
		# Adjacent safe lanes: 92-96 px travel, < warning*245. Designed
		# reversals with small seeded variation, never an arbitrary full-width jump.
		var step := (1 if int(i/3)%2 == 0 else -1)
		if i%4 == 3:
			step = rng.randi_range(-1,1)
		lane = clampi(lane+step,0,4)
		var lane_width := arena.size.x/5
		var gap_width := 78.0 if extreme else 84.0
		var center := arena.position.x + lane_width*(lane+0.5) + rng.randf_range(-3,3)
		var gap := Rect2(center-gap_width/2,arena.position.y,gap_width,arena.size.y)
		var blocks: Array[Rect2] = []
		if gap.position.x > arena.position.x:
			blocks.append(Rect2(arena.position,Vector2(gap.position.x-arena.position.x,arena.size.y)))
		if gap.end.x < arena.end.x:
			blocks.append(Rect2(Vector2(gap.end.x,arena.position.y),Vector2(arena.end.x-gap.end.x,arena.size.y)))
		pillars.append({"impact":target,"warning":target-pillar_warning-pillar_fall,"fall":target-pillar_fall,"gap":gap,"blocks":blocks})

func shapes_at(time: float) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var arena: Rect2 = Cue.BOXES[stage] if stage >= 0 else battle.arena_rect
	var age := time-phase_start
	if stage in [1,6]:
		for p in pillars:
			if time < p.warning or time >= p.impact+floor_hold+retract:
				continue
			var warning: bool = time < p.fall
			var descent := clampf((time-p.fall)/pillar_fall,0,1)
			var withdrawal := clampf((time-p.impact-floor_hold)/retract,0,1)
			for block in p.blocks:
				var body: Rect2 = block
				body.position.y -= body.size.y*(1-descent*descent + withdrawal*withdrawal)
				if warning:
					body = Rect2(Vector2(block.position.x,arena.end.y-5),Vector2(block.size.x,5))
				shapes.append({"rect":body,"warning":warning,"tint":Color("#FF6E7E") if warning else Color("#08090C"),"pillar":true})
	elif stage == 2:
		var inner := arena.grow(-BALL_RADIUS-2)
		var distance := Vector2(239,187)*maxf(0,age)
		var pos := inner.position + Vector2(triangle(distance.x,inner.size.x),triangle(distance.y,inner.size.y))
		shapes.append({"circle":pos,"radius":BALL_RADIUS,"warning":age < 0.7,"tint":Color("#FF637F")})
	elif stage == 4:
		# Alternating axes avoid impossible simultaneous crossing walls. Each
		# cycle gives a 0.7 s warning, 2.9 s sweep, then an open release interval.
		var cycle := int(maxf(age,0)/4.2)
		var local := fposmod(age,4.2)
		var vertical := cycle%2 == 0
		var sweep := smoothstep(0.7,3.6,local)
		var progress := sweep if cycle%4 < 2 else 1-sweep
		if local < 3.6:
			var center := arena.position + arena.size*(Vector2(progress,0) if vertical else Vector2(0,progress))
			var body := Rect2(center-Vector2(6,0),Vector2(12,arena.size.y)) if vertical else Rect2(center-Vector2(0,6),Vector2(arena.size.x,12))
			# Split at a fixed, visible corridor: the player always has a route
			# through each sweep. Corridors alternate in a predictable pattern.
			var gap := 78.0
			var fraction: float = [0.30,0.66,0.70,0.34][cycle%4]
			var gap_center := (arena.position.y+arena.size.y*fraction) if vertical else (arena.position.x+arena.size.x*fraction)
			var first := body
			var second := body
			if vertical:
				first.size.y = gap_center-gap/2-body.position.y
				second.position.y = gap_center+gap/2
				second.size.y = body.end.y-second.position.y
			else:
				first.size.x = gap_center-gap/2-body.position.x
				second.position.x = gap_center+gap/2
				second.size.x = body.end.x-second.position.x
			for piece in [first,second]:
				shapes.append({"rect":piece,"warning":local < 0.7,"tint":Color("#FF3654"),"laser":true})
	elif stage == 5:
		# 1.9 s spacing exceeds the longest jump cycle (~0.75 s) plus landing
		# recovery; even the tallest 72 px beam is below the 86 px held apex.
		for i in range(8):
			var start := phase_start+0.7+i*1.9
			var speed := 255.0+i%3*20.0
			var x := arena.end.x+30-(time-start)*speed
			if time < start-0.65 or x < arena.position.x-30:
				continue
			var height: float = [38.0,56.0,72.0][i%3]
			var body := Rect2((arena.end.x-14 if time < start else x-7),arena.end.y-height,14,height)
			shapes.append({"rect":body,"warning":time < start,"tint":Color("#FFBE7B"),"laser":true})
	return shapes

static func triangle(distance: float, width: float) -> float:
	return width-absf(fposmod(distance,2*width)-width)

static func circle_hits_rect(point: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := point.clamp(rect.position,rect.end)
	return point.distance_squared_to(nearest) < radius*radius

func stop_damage() -> void:
	if damaging:
		ghosts = shapes_at(clock)
	damaging = false

func clear() -> void:
	damaging = false
	ghosts.clear()
	debris.clear()
	pillars.clear()
	stage = -1

func advance(time: float, collisions: bool = false) -> void:
	clock = time
	# Impacts are recorded at their scheduled musical position, even when a
	# frame spans the timestamp. Seeking never replays a backlog of damage.
	if damaging and stage in [1,6]:
		for i in range(pillars.size()):
			var p: Dictionary = pillars[i]
			if time >= p.impact and not impacts_seen.has(i):
				impacts_seen[i] = true
				impact_log.append(p.impact)
				if time-p.impact < 0.18:
					for edge in [p.gap.position.x-12,p.gap.end.x+12]:
						for j in range(8 if stage == 6 else 5):
							debris.append({"point":Vector2(edge,Cue.BOXES[stage].end.y),"start":p.impact,"velocity":Vector2((j-3)*37,-110-j*18)})
	if collisions and damaging and not battle.player.transition_safe:
		# Subsample one real frame (up to 1/15 s), including star movement.
		# This prevents tunneling by a fast beam/ball without historical hits.
		var begin := maxf(last_clock,time-1.0/15)
		var samples := maxi(1,ceili((time-begin)*240))
		for j in range(samples+1):
			var blend := float(j)/samples
			var sample_time := lerpf(begin,time,blend)
			var player_pos: Vector2 = battle.player.previous_position.lerp(battle.player.position,blend)
			for shape in shapes_at(sample_time):
				if shape.warning:
					continue
				var hit := false
				if shape.has("circle"):
					hit = player_pos.distance_to(shape.circle) < shape.radius+battle.player.RADIUS
				else:
					hit = circle_hits_rect(player_pos,battle.player.RADIUS,shape.rect)
				if hit:
					battle.player.take_damage()
	if collisions:
		last_clock = time
	debris = debris.filter(func(p): return time-p.start < 0.5)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not battle.game_over and not battle.victory_started:
		advance(battle.elapsed_time,true)

func _draw_shape(shape: Dictionary, alpha: float) -> void:
	var tint: Color = shape.tint
	tint.a = alpha*(0.55+0.25*sin(clock*24) if shape.warning else 1.0)
	if shape.has("circle"):
		draw_circle(shape.circle,shape.radius+5,Color(tint,0.09*alpha))
		draw_circle(shape.circle,shape.radius,tint,not shape.warning,2 if shape.warning else -1,true)
		draw_arc(shape.circle,shape.radius-7,clock*3,clock*3+PI*1.4,32,Color(1,1,1,0.7*alpha),1.5,true)
	else:
		var rect: Rect2 = shape.rect
		if shape.get("laser",false) and not shape.warning:
			draw_rect(rect.grow(5),Color(tint,0.07*alpha))
			draw_rect(rect,tint)
			draw_rect(rect.grow(-3),Color(1,0.9,0.85,alpha))
		elif shape.get("pillar",false) and not shape.warning:
			draw_rect(rect,tint)
			draw_rect(rect,Color(0.8,0.79,0.84,alpha),false,2,true)
			draw_line(rect.position+Vector2(7,0),rect.position+Vector2(7,rect.size.y),Color(0.4,0.4,0.45,alpha),1)
		else:
			draw_rect(rect,tint,false,1.5,true)

func _draw() -> void:
	# Clip every hazard to the box; the live collision uses the same rectangle.
	var active: Array[Dictionary] = []
	if damaging:
		active = shapes_at(clock)
	for shape in active:
		_draw_shape(shape,1)
	var target := Cue.morph_at(clock)
	var fade := 0.0 if target < 0 else 1-smoothstep(0,0.3,clock-(Cue.STARTS[target]-Cue.MORPH))
	for shape in ghosts:
		_draw_shape(shape,fade)
	for p in debris:
		var age: float = clock-p.start
		var pos: Vector2 = p.point+p.velocity*age+Vector2(0,280)*age*age
		draw_rect(Rect2(pos,Vector2(3,3)),Color(0.9,0.88,0.87,(1-age/0.5)*0.7))
