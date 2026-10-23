extends Node2D
## Analytic hazards share the soundtrack clock; no spawning timers, physics
## impulses or delayed callbacks can leak across retries or stage changes.
const Cue = preload("res://scripts/blankkitten/timeline.gd")
const BALL_RADIUS := 73.0
const BALL_VISUAL_RADIUS := 85.0
const WALL_DEPTH := 9.0
const LANES := 8
const BALL_SPEED := Vector2(79,67)
var wall_quad: ColorRect
var wall_material: ShaderMaterial
var warning_seen: Dictionary = {}
var ball_quad: ColorRect
var ball_material: ShaderMaterial
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
var last_ball_cell := Vector2i.ZERO
var last_laser_cycle := -1
var graze_until := 0.0
var pillar_warning := 1.1
var pillar_fall := 0.16
var floor_hold := 0.14
var retract := 0.16

func _ready() -> void:
	if battle == null:
		battle = get_parent().get_parent()
	process_physics_priority = 0
	ball_quad = ColorRect.new()
	ball_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_quad.size = Vector2.ONE*BALL_VISUAL_RADIUS*2
	ball_quad.z_index = 1
	ball_material = ShaderMaterial.new()
	ball_material.shader = preload("res://shaders/blankkitten_fireball.gdshader")
	ball_material.set_shader_parameter("human_core",preload("res://assets/overhaul_human/ninja/nova_00.png"))
	ball_material.set_shader_parameter("human_flame",preload("res://assets/overhaul_human/ninja/flame_00.png"))
	ball_quad.material = ball_material
	add_child(ball_quad)
	ball_quad.hide()
	wall_quad = ColorRect.new()
	wall_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_material = ShaderMaterial.new()
	wall_material.shader = preload("res://shaders/blankkitten_walls.gdshader")
	wall_quad.material = wall_material
	add_child(wall_quad)
	wall_quad.hide()

func configure(next: int) -> void:
	stage = next
	phase_start = Cue.STARTS[stage]
	damaging = stage in [1,2,4,5,6]
	pillars.clear()
	impacts_seen.clear()
	warning_seen.clear()
	debris.clear()
	ghosts.clear()
	last_ball_cell = Vector2i.ZERO
	last_laser_cycle = -1
	graze_until = 0
	last_clock = phase_start
	if stage in [1,6]:
		build_pillars(stage == 6)

func build_pillars(extreme: bool) -> void:
	pillar_warning = 1.12 if extreme else 1.20
	pillar_fall = 0.18
	var grid := Cue.HALF_MEASURE if extreme else Cue.MEASURE
	var offset: float = battle.cue_sheet.musical_phase_offset
	var first: float = offset + ceil((phase_start + pillar_warning + pillar_fall - offset) / grid)*grid
	var arena: Rect2 = Cue.BOXES[stage]
	var lane_width := arena.size.x / LANES
	var safe_lane := 3
	var previous_center := 4.0
	var sequence := [0,1,1,0,-1,-1,0,1,0,1,-1,0,-1,1]
	var variation := posmod(int(battle.cue_sheet.pattern_seed),sequence.size())
	for i in range(32 if extreme else 11):
		var target := first + i*grid
		if target+floor_hold+retract >= Cue.STARTS[stage+1]-Cue.MORPH:
			break
		safe_lane = clampi(safe_lane+sequence[(i+variation)%sequence.size()],1,6)
		var safe_count := 1 if extreme and i%3 != 0 and target < 127 else 2
		var center_lane := safe_lane+safe_count*.5
		if absf(center_lane-previous_center) > 1:
			safe_lane += -1 if center_lane > previous_center else 1
		previous_center = safe_lane+safe_count*.5
		var safe_begin := safe_lane
		var gap := Rect2(arena.position+Vector2(safe_begin*lane_width,0),Vector2(safe_count*lane_width,arena.size.y))
		var blocks: Array[Rect2] = []
		var mask := 0
		for lane in LANES:
			if lane >= safe_begin and lane < safe_begin+safe_count: continue
			# Early patterns leave additional alternating openings; later phrases
			# retain the explicit reachable corridor while combining adjacent lanes.
			if not extreme and i < 3 and lane%2 == i%2: continue
			if i%5 == 3 and lane == (safe_begin+4)%LANES: continue
			mask |= 1 << lane
			blocks.append(Rect2(arena.position+Vector2(lane*lane_width,0),Vector2(lane_width,arena.size.y)))
		var warning := maxf(phase_start,target-pillar_warning-pillar_fall)
		if not pillars.is_empty(): warning = maxf(warning,pillars[-1].impact+floor_hold+.04)
		pillars.append({"impact":target,"warning":warning,"fall":target-pillar_fall,"gap":gap,"blocks":blocks,"mask":mask,"phrase":i,"climax":extreme and target >= 127})

func ball_position(time: float) -> Vector2:
	var arena: Rect2 = Cue.BOXES[2]
	var inner := arena.grow(-BALL_VISUAL_RADIUS-WALL_DEPTH)
	var distance := BALL_SPEED*maxf(0,time-Cue.STARTS[2])
	return inner.position+Vector2(triangle(distance.x,inner.size.x),triangle(distance.y,inner.size.y))

func grid_pocket(time: float) -> Rect2:
	var arena: Rect2 = Cue.BOXES[4]
	var age := maxf(0,time-Cue.STARTS[4])
	var cycle := int(age/4.0)
	var local := fposmod(age,4.0)
	var centers := [Vector2(.5,.5),Vector2(.35,.4),Vector2(.65,.4),Vector2(.65,.65),Vector2(.35,.65),Vector2(.5,.5)]
	var center: Vector2 = centers[mini(cycle,4)].lerp(centers[mini(cycle+1,5)],smoothstep(.9,3.3,local))
	var gap := lerpf(112,88,clampf(age/18,0,1))
	return Rect2(arena.position+arena.size*center-Vector2.ONE*gap/2,Vector2.ONE*gap)

func jump_pairs() -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for i in 6:
		pairs.append({"start":Cue.STARTS[5]+1.05+i*2.25,"speed":210.0+i%3*12,"height":[20.0,34.0,24.0,40.0,30.0,38.0][i],"gap":[50.0,56.0,52.0,58.0,54.0,56.0][i],"direction":-1 if i%3 != 2 else 1,"id":i})
	return pairs

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
		shapes.append({"circle":ball_position(time),"radius":BALL_RADIUS,"warning":age < 0.8,"tint":Color("#FF8838"),"fireball":true})
		for wall in [Rect2(arena.position,Vector2(arena.size.x,WALL_DEPTH)),Rect2(Vector2(arena.position.x,arena.end.y-WALL_DEPTH),Vector2(arena.size.x,WALL_DEPTH)),Rect2(arena.position,Vector2(WALL_DEPTH,arena.size.y)),Rect2(Vector2(arena.end.x-WALL_DEPTH,arena.position.y),Vector2(WALL_DEPTH,arena.size.y))]:
			shapes.append({"rect":wall,"warning":false,"tint":Color("#FF6934"),"wall":true})
	elif stage == 4:
		var cycle := int(maxf(age,0)/4)
		var local := fposmod(age,4)
		var pocket := grid_pocket(time)
		if local < 3.65:
			var sweep := smoothstep(.9,3.45,local)
			for axis in (1 if cycle == 0 else 2):
				var vertical := axis == 0
				var warning := local < (.9 if axis == 0 else 1.25)
				var progress := sweep if cycle%2 == 0 else 1-sweep
				if axis == 1: progress = 1-progress
				var center := arena.position+arena.size*(Vector2(progress,0) if vertical else Vector2(0,progress))
				var body := Rect2(center-Vector2(4,0),Vector2(8,arena.size.y)) if vertical else Rect2(center-Vector2(0,4),Vector2(arena.size.x,8))
				for replica in (2 if cycle >= 3 and vertical else 1):
					var first := body
					var second := body
					if replica == 1:
						first.position.x = arena.position.x+arena.size.x*(1-progress)-4
						second.position.x = first.position.x
					if vertical:
						first.size.y = pocket.position.y-arena.position.y
						second.position.y = pocket.end.y
						second.size.y = arena.end.y-pocket.end.y
					else:
						first.size.x = pocket.position.x-arena.position.x
						second.position.x = pocket.end.x
						second.size.x = arena.end.x-pocket.end.x
					for piece in [first,second]:
						shapes.append({"rect":piece,"warning":warning,"tint":Color("#FC526D") if vertical else Color("#A17BFF"),"laser":true,"axis":axis,"cycle":cycle})
	elif stage == 5:
		for pair in jump_pairs():
			var x: float = (arena.end.x+20 if pair.direction < 0 else arena.position.x-20)+(time-pair.start)*pair.speed*pair.direction
			if time < pair.start-.95: continue
			if time >= pair.start and (x < arena.position.x-24 or x > arena.end.x+24): continue
			var warning: bool = time < pair.start
			if warning: x = arena.end.x-7 if pair.direction < 0 else arena.position.x+7
			var bottom := Rect2(x-7,arena.end.y-pair.height,14,pair.height)
			var top := Rect2(x-7,arena.position.y,14,arena.size.y-pair.height-pair.gap)
			for piece in [bottom,top]:
				shapes.append({"rect":piece,"warning":warning,"tint":Color("#FFC68B"),"paired":true,"pair":pair.id,"direction":pair.direction})
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
	ball_quad.hide()
	wall_quad.hide()

func advance(time: float, collisions: bool = false) -> void:
	clock = time
	wall_quad.visible = stage == 2 and damaging
	if wall_quad.visible:
		wall_quad.position = battle.arena_rect.position
		wall_quad.size = battle.arena_rect.size
		wall_material.set_shader_parameter("clock",time)
		wall_material.set_shader_parameter("arena_size",battle.arena_rect.size)
	ball_quad.visible = stage == 2 and damaging
	if ball_quad.visible:
		ball_quad.position = ball_position(time)-Vector2.ONE*BALL_VISUAL_RADIUS
		ball_quad.modulate.a = .5 if time-phase_start < .8 else 1.0
		ball_material.set_shader_parameter("clock",time)
		ball_material.set_shader_parameter("reduced",1.0 if battle.reduced_effects else 0.0)
	# Impacts are recorded at their scheduled musical position, even when a
	# frame spans the timestamp. Seeking never replays a backlog of damage.
	if damaging and stage in [1,6]:
		for i in range(pillars.size()):
			var p: Dictionary = pillars[i]
			if time >= p.warning and not warning_seen.has(i):
				warning_seen[i] = true
				if time-p.warning < .15: battle.feedback.cue("warning",time)
			if time >= p.impact and not impacts_seen.has(i):
				impacts_seen[i] = true
				impact_log.append(p.impact)
				if time-p.impact < 0.18:
					for block in p.blocks:
						var point: Vector2 = Vector2(block.get_center().x,Cue.BOXES[stage].end.y)
						battle.feedback.impact(point,(1.25 if p.climax else 1.0) if stage == 6 else .6,p.impact)
	if damaging and stage == 2:
		var inner := Cue.BOXES[2].grow(-BALL_VISUAL_RADIUS-WALL_DEPTH)
		var travel := BALL_SPEED*maxf(0,time-phase_start)
		var cell := Vector2i(floor(travel.x/inner.size.x),floor(travel.y/inner.size.y))
		if cell != last_ball_cell and time-last_clock < .2:
			battle.feedback.bounce(ball_position(time),time)
		last_ball_cell = cell
	if damaging and stage == 4:
		var cycle := int(maxf(0,time-phase_start)/4)
		if fposmod(time-phase_start,4) >= .9 and cycle != last_laser_cycle:
			last_laser_cycle = cycle
			battle.feedback.cue("laser",time)
	if damaging and stage == 5:
		for pair in jump_pairs():
			if time >= pair.start-.95 and not warning_seen.has(pair.id):
				warning_seen[pair.id] = true
				if time-pair.start+.95 < .15: battle.feedback.cue("beam",time)
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
				elif time >= graze_until and not shape.get("wall",false):
					var close: bool = player_pos.distance_to(shape.circle) < shape.radius+battle.player.RADIUS+8 if shape.has("circle") else circle_hits_rect(player_pos,battle.player.RADIUS+8,shape.rect)
					if close:
						graze_until = time+.65
						battle.feedback.graze(player_pos,time)
	if collisions:
		last_clock = time
	debris = debris.filter(func(p): return time-p.start < 0.5)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not battle.game_over and not battle.victory_started:
		advance(battle.elapsed_time,true)

func _draw_shape(shape: Dictionary, alpha: float) -> void:
	preload("res://scripts/blankkitten/hazard_style.gd").draw_shape(self,shape,clock,alpha,battle.reduced_effects)

func _draw() -> void:
	if damaging:
		# Analytic, non-damaging fire trail; no nodes accumulate behind the ball.
		if stage == 2:
			for i in range(12,0,-1):
				var point := ball_position(maxf(phase_start,clock-i*.045))
				draw_circle(point,BALL_VISUAL_RADIUS*(1-i*.04),Color(1,.15,.025,.025*(1-i/14.0)))
		for shape in shapes_at(clock): _draw_shape(shape,1)
		if stage == 4:
			preload("res://scripts/blankkitten/hazard_style.gd").intersections(self,shapes_at(clock),clock,battle.reduced_effects)
	var target := Cue.morph_at(clock)
	var fade := 0.0 if target < 0 else 1-smoothstep(0,.3,clock-(Cue.STARTS[target]-Cue.MORPH))
	for shape in ghosts: _draw_shape(shape,fade)
