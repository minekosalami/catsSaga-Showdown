extends Node2D
const Cfg = preload("res://scripts/incarna/config.gd")
const Art = preload("res://scripts/incarna/art.gd")
const Energy = preload("res://scripts/ui/projectile_energy.gd")
var battle: Node
var rig: Node2D
var clock := 0.0
var section := 0
var events: Array[Dictionary] = []
var cursor := 0
var barrages: Array[Dictionary] = []
var lunges: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var previous_paws: Array[Vector2] = []
var rng := RandomNumberGenerator.new()
var fired_log: Array[Dictionary] = []
var cue_log: Array[float] = []
var spear_texture: AtlasTexture
var next_id := 0
var damage_enabled := true

func initialize(owner_battle: Node, owner_rig: Node2D) -> void:
	battle = owner_battle
	rig = owner_rig
	process_physics_priority = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spear_texture = Art.atlas("spear")
	rng.seed = Cfg.PATTERN_SEED
	for s in range(1,7):
		var tune: Dictionary = Cfg.tuning(s)
		var t: float = Cfg.CUES[s]
		var index := 0
		while t < Cfg.CUES[s+1]-.75:
			var kind: String = ["spear","paw","zone"][index%3]
			events.append({"time":t,"kind":kind,"section":s,"index":index})
			if s >= 2 and kind != "zone" and t+Cfg.MEASURE < Cfg.CUES[s+1]-.5:
				events.append({"time":t+Cfg.MEASURE,"kind":"zone","section":s,"index":index})
			t += tune.cadence
			index += 1
		if s in [2,3,4]:
			var glare: float = Cfg.CUES[s]+Cfg.BEAT*2
			while glare < Cfg.CUES[s+1]-1:
				events.append({"time":glare,"kind":"glare","section":s,"index":0})
				glare += Cfg.MEASURE if s == 2 else Cfg.BEAT*2
	events.sort_custom(func(a: Dictionary,b: Dictionary): return a.time < b.time)

func reset_clock(time: float) -> void:
	clear()
	rig.impulses.clear()
	damage_enabled = true
	section = Cfg.section_at(time)
	clock = time
	cursor = 0
	while cursor < events.size() and events[cursor].time < time: cursor += 1
	rng.seed = Cfg.PATTERN_SEED
	rig.sample(time,battle.player.hit_center(),[])
	previous_paws.assign(rig.rest_tips)

func advance(time: float) -> void:
	if time < clock: reset_clock(time)
	clock = minf(time,Cfg.END)
	var next := Cfg.section_at(clock)
	if next != section:
		section = next
		cue_log.append(Cfg.CUES[section])
		if section == 4:
			# Release the anticipation, then answer the returning beat with the rig.
			rig.push_impulse(clock,2.0)
			shots.clear()
			zones.clear()
			lunges.clear()
			barrages.clear()
	var anticipating := clock >= Cfg.RETURN_PREP and clock < Cfg.CUES[4]
	while cursor < events.size() and events[cursor].time <= clock:
		var event: Dictionary = events[cursor]
		cursor += 1
		if clock-event.time > .18 or anticipating or not damage_enabled: continue
		issue(event)
	previous_paws.assign(rig.rest_tips)
	rig.sample(clock,battle.player.hit_center(),lunges)
	for barrage in barrages:
		while barrage.emitted < barrage.count:
			var shot_time: float = barrage.start+Cfg.SPEAR_WARNING+barrage.emitted*Cfg.SPEAR_SPACING
			if shot_time > clock+.000001: break
			barrage.emitted += 1
			if clock-shot_time > .15 or anticipating: continue
			var origin: Vector2 = rig.mounts[barrage.mount]
			var target: Vector2 = battle.player.hit_center()
			fire(origin,(target-origin).normalized(),barrage.speed,"spear",shot_time)
			fired_log.append({"id":barrage.id,"time":shot_time,"target":target,"origin":origin})
			rig.push_impulse(clock,.65)
	barrages = barrages.filter(func(b: Dictionary): return clock < b.start+Cfg.SPEAR_WARNING+b.count*Cfg.SPEAR_SPACING+.25)
	for zone in zones:
		if clock >= zone.start+Cfg.BURST_WARNING and not zone.exploded:
			zone.exploded = true
			if clock-zone.start-Cfg.BURST_WARNING > .18: continue
			var offset: float = rng.randf_range(0,TAU)
			for i in zone.fragments:
				var direction := Vector2.RIGHT.rotated(offset+TAU*i/zone.fragments+rng.randf_range(-.025,.025))
				fire(zone.point,direction,rng.randf_range(165,255),"fragment",zone.start+Cfg.BURST_WARNING)
	lunges = lunges.filter(func(a: Dictionary): return clock < a.start+Cfg.LUNGE_WARNING+Cfg.LUNGE_TRAVEL+Cfg.LUNGE_HOLD+Cfg.LUNGE_RETURN)
	zones = zones.filter(func(a: Dictionary): return clock < a.start+Cfg.BURST_WARNING+.22)
	# Analytic positions stay on the soundtrack clock even if a render frame drops.
	for shot in shots: shot.point = shot.origin+shot.direction*shot.speed*maxf(0,clock-shot.born)
	shots = shots.filter(func(s: Dictionary): return Rect2(-180,-180,1640,1080).has_point(s.point) and clock-s.born < 9)
	queue_redraw()

func issue(event: Dictionary) -> void:
	var tune: Dictionary = Cfg.tuning(event.section)
	match event.kind:
		"spear":
			barrages.append({"id":next_id,"start":event.time,"mount":event.index%2,"count":tune.spears,"speed":tune.speed,"emitted":0})
			next_id += 1
		"paw":
			var count := 2 if event.section in [3,4] else 1
			for i in count:
				var target: Vector2 = battle.player.hit_center()+Vector2((i*2-1)*95 if count == 2 else 0,0)
				target = target.clamp(Cfg.PLAY_AREA.position+Vector2.ONE*50,Cfg.PLAY_AREA.end-Vector2.ONE*50)
				lunges.append({"start":event.time+i*.22,"paw":(event.index+i)%2,"target":target})
		"zone":
			for i in tune.zones:
				if zones.size() >= Cfg.MAX_ZONES: break
				var point := Vector2(rng.randf_range(160,1120),rng.randf_range(475,610))
				for attempt in range(10):
					var too_close := false
					for old in zones:
						if point.distance_to(old.point) < 170: too_close = true
					if not too_close: break
					point = Vector2(rng.randf_range(160,1120),rng.randf_range(475,610))
				zones.append({"point":point,"radius":48.0,"start":event.time+i*.24,"exploded":false,"fragments":tune.fragments})
		"glare":
			var origin: Vector2 = rig.eyes[event.section%6].global_position
			var aim: Vector2 = (battle.player.hit_center()-origin).normalized()
			var half := 3 if event.section == 2 else (4 if event.section == 3 else 5)
			for i in range(-half,half+1): fire(origin,aim.rotated(i*.16),240 if event.section == 2 else (310 if event.section == 3 else 350),"fragment",event.time)

func fire(origin: Vector2, direction: Vector2, speed: float, kind: String, born: float) -> void:
	if kind != "spear" and shots.size() >= Cfg.MAX_SHOTS-Cfg.SPEAR_RESERVE: return
	if kind == "spear" and shots.size() >= Cfg.MAX_SHOTS:
		# Fragment pressure never suppresses the signature tracking barrage.
		for i in shots.size():
			if shots[i].kind != "spear":
				shots.remove_at(i)
				break
	if shots.size() >= Cfg.MAX_SHOTS: return
	shots.append({"origin":origin,"point":origin,"previous":origin,"direction":direction,"speed":speed,"kind":kind,"born":born,"radius":4.5 if kind == "spear" else 5.0,"length":108.0 if kind == "spear" else 0.0})

static func segments_distance(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a,b,c,d) != null: return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d)),b.distance_to(Geometry2D.get_closest_point_to_segment(b,c,d))),minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)),d.distance_to(Geometry2D.get_closest_point_to_segment(d,a,b))))

func collide() -> void:
	if not damage_enabled or battle.player.entrance_locked or battle.game_over or battle.victory_started: return
	var player: Node = battle.player
	var now: Vector2 = player.hit_center()
	var before: Vector2 = player.previous_hit_center
	for shot in shots:
		var a: Vector2 = shot.previous-before
		var b: Vector2 = shot.point-now
		var tail: Vector2 = -shot.direction*shot.length
		if segments_distance(a,b,tail,Vector2.ZERO) <= shot.radius+player.damage_hitbox_radius:
			player.take_damage(1)
			shot.dead = true
		shot.previous = shot.point
	shots = shots.filter(func(s: Dictionary): return not s.get("dead",false))
	for attack in lunges:
		var age: float = clock-attack.start-Cfg.LUNGE_WARNING
		if age >= 0 and age <= Cfg.LUNGE_TRAVEL+Cfg.LUNGE_HOLD:
			var tip: Vector2 = rig.paw_tip(attack.paw)
			var old: Vector2 = previous_paws[attack.paw] if previous_paws.size() > attack.paw else tip
			if Geometry2D.get_closest_point_to_segment(Vector2.ZERO,old-before,tip-now).length() <= Cfg.PAW_RADIUS+player.damage_hitbox_radius:
				player.take_damage(1)
	for zone in zones:
		if zone.exploded and clock-zone.start-Cfg.BURST_WARNING <= .12 and now.distance_to(zone.point) <= zone.radius+player.damage_hitbox_radius: player.take_damage(1)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(battle): collide()

func clear() -> void:
	damage_enabled = false
	shots.clear()
	barrages.clear()
	lunges.clear()
	zones.clear()
	queue_redraw()

func _draw() -> void:
	# Restrained corner guides expose movement limits without boxing the scene in.
	for corner in [Cfg.PLAY_AREA.position,Vector2(Cfg.PLAY_AREA.end.x,Cfg.PLAY_AREA.position.y),Cfg.PLAY_AREA.end,Vector2(Cfg.PLAY_AREA.position.x,Cfg.PLAY_AREA.end.y)]:
		var inward: Vector2 = (Cfg.PLAY_AREA.get_center()-corner).sign()
		draw_line(corner,corner+Vector2(inward.x*15,0),Color(1,1,1,.18),1,true)
		draw_line(corner,corner+Vector2(0,inward.y*15),Color(1,1,1,.18),1,true)
	for barrage in barrages:
		if clock >= barrage.start+Cfg.SPEAR_WARNING: continue
		var origin: Vector2 = rig.mounts[barrage.mount]
		var target: Vector2 = battle.player.hit_center()
		var progress: float = clampf((clock-barrage.start)/Cfg.SPEAR_WARNING,0,1)
		draw_dashed_line(origin,target,Color(1,.22,.18,.35+progress*.45),2,12)
		draw_arc(target,18+12*(1-progress),0,TAU,32,Color("#FFE093"),2,true)
	for attack in lunges:
		var age: float = clock-attack.start
		if age < Cfg.LUNGE_WARNING:
			var progress: float = clampf(age/Cfg.LUNGE_WARNING,0,1)
			draw_dashed_line(rig.paw_tip(attack.paw),attack.target,Color(1,.2,.18,.55),1.5,10)
			draw_circle(attack.target,Cfg.PAW_RADIUS+10,Color(1,.12,.1,.09))
			draw_arc(attack.target,Cfg.PAW_RADIUS+10,0,TAU,48,Color("#FF6056"),1.5+progress,true)
		elif age < Cfg.LUNGE_WARNING+Cfg.LUNGE_TRAVEL+Cfg.LUNGE_HOLD:
			draw_arc(rig.paw_tip(attack.paw),Cfg.PAW_RADIUS,0,TAU,32,Color(1,.55,.28,.7),1,true)
	for zone in zones:
		var progress: float = clampf((clock-zone.start)/Cfg.BURST_WARNING,0,1)
		if not zone.exploded:
			draw_circle(zone.point,zone.radius,Color(1,.2,.1,.07))
			draw_arc(zone.point,zone.radius,0,TAU,48,Color("#FFD772"),1.8,true)
			draw_arc(zone.point,zone.radius-5,-PI*.5,-PI*.5+TAU*progress,48,Color("#FF6B53"),2,true)
		else:
			var fade: float = 1-clampf((clock-zone.start-Cfg.BURST_WARNING)/.22,0,1)
			draw_circle(zone.point,zone.radius,Color(1,.6,.28,fade*.25))
	for shot in shots:
		if shot.kind == "spear":
			# Sheet's spear points from bottom-left to top-right; origin is its tip.
			var region: Rect2 = Art.REGIONS.spear
			var natural := Vector2(region.size.x,-region.size.y).angle()
			draw_set_transform(shot.point,shot.direction.angle()-natural)
			draw_texture_rect(spear_texture,Rect2(Vector2(-region.size.x,0)*.17,region.size*.17),false,Color(1.7,1.7,1.7))
		else:
			draw_set_transform(shot.point)
			Energy.draw_orb(self,shot.radius,Color("#FFF2D6"),clock-shot.born)
	draw_set_transform(Vector2.ZERO)
