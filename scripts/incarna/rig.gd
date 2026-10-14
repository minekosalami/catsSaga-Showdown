extends Node2D
const Cfg = preload("res://scripts/incarna/config.gd")
const Part = preload("res://scripts/incarna/part.gd")
@export var preview_mode := false
var pieces: Dictionary = {}
var paws: Array[Node2D] = []
var eyes: Array[Node2D] = []
var cables: Array[PackedVector2Array] = []
var mounts: Array[Vector2] = []
var clock := 0.0
var preview_age := 0.0
var impulses: Array[Dictionary] = []
var emergence := 0.0
var rest_tips: Array[Vector2] = []

func add_part(id: String, kind: String, width: float, flex: float = 1.0) -> Node2D:
	var part := Part.new()
	part.name = id
	part.build(kind,width,flex)
	add_child(part)
	pieces[id] = part
	return part

func _ready() -> void:
	add_part("Machine","base",870,0).z_index = -3
	add_part("Cord","cord",1060,.16).z_index = -2
	for i in range(5):
		add_part("Head%d"%i,"head" if i in [0,4] else "mask",310 if i in [0,4] else 335,.8).z_index = 1
		if i in [2,4]: pieces["Head%d"%i].scale.x = -1
	for i in range(2):
		var paw := add_part("Paw%d"%i,"paw",120,1.5)
		paw.z_index = 3
		paws.append(paw)
		add_part("SpearMount%d"%i,"spear",112,.1).z_index = 0
	for i in range(7):
		var eye := add_part("Eye%d"%i,"eye_left" if i%2 == 0 else "eye_right",85 if i < 6 else 145,.15)
		eye.z_index = 4
		eyes.append(eye)
	sample(10 if preview_mode else 0,Vector2(640,600),[])

func _process(delta: float) -> void:
	if preview_mode:
		preview_age += delta
		sample(10+preview_age,get_parent().host.player.global_position,[])

func push_impulse(time: float, weight: float = 1.0) -> void:
	impulses.append({"time":time,"weight":weight})
	if impulses.size() > 20: impulses.pop_front()

func creep(time: float) -> float:
	var p := smoothstep(0,Cfg.EMERGENCE,time)*.48
	for start in [0.5,2.8,5.1,7.4]: p += smoothstep(start,start+2.4,time)*.13
	return clampf(p,0,1)

func sample(time: float, player_point: Vector2, lunges: Array) -> void:
	clock = time
	emergence = creep(time)
	if not preview_mode:
		position = Cfg.RIG_CENTER+Vector2(sin(time*.29)*13,-350*(1-emergence)+sin(time*.72)*4)
	var breath := sin(time*.83)*5+sin(time*.37+1)*3
	var recoil := 0.0
	for impulse in impulses:
		var age: float = time-impulse.time
		if age >= 0 and age < 1.2: recoil += sin(age*15)*exp(-age*5)*impulse.weight*6
	recoil = tanh(recoil/8)*8
	pieces.Machine.position = Vector2(sin(time*.29)*7,275+breath+recoil)
	pieces.Machine.rotation = sin(time*.27)*.017
	pieces.Cord.position = Vector2(0,breath*.6)
	pieces.Cord.rotation = sin(time*.21)*.025
	cables.clear()
	var rests := [Vector2(-385,335),Vector2(-155,285),Vector2(155,285),Vector2(0,470),Vector2(385,335)]
	# Two interior heads exchange sockets along opposed arcs, retaining tethers.
	var cycle := fposmod(time, Cfg.MEASURE*12)
	var exchange := smoothstep(Cfg.MEASURE*7,Cfg.MEASURE*9,cycle)-smoothstep(Cfg.MEASURE*10,Cfg.MEASURE*12,cycle)
	for i in range(5):
		var head: Node2D = pieces["Head%d"%i]
		var point: Vector2 = rests[i]
		if i in [1,2]:
			var side := -1.0 if i == 1 else 1.0
			point.x = lerpf(side*155,-side*155,exchange)
			point.y += sin(exchange*PI)*side*68
		point += Vector2(sin(time*.62-i*.35)*9,breath+sin(time*.82-i*.25)*7)
		head.position = point
		head.rotation = sin(time*.57-i*.32)*.035
		head.flex(time-i*.14,i*.8)
		cable(Vector2(point.x*.43,70),point-Vector2(0,85),time+i)
	for i in range(6):
		var head_index := 1+i/2
		var head: Node2D = pieces["Head%d"%head_index]
		var gaze := (player_point-to_global(head.position)).normalized()*5
		eyes[i].position = head.position+Vector2(-65 if i%2 == 0 else 65,-25)+gaze
		eyes[i].rotation = head.rotation
		var blink_age := fposmod(time-i*.19,6.7)
		var close := 1.0-.93*sin(PI*blink_age/.23) if blink_age < .23 else 1.0
		eyes[i].flex(time,0,0,close)
	eyes[6].position = Vector2(sin(time*.41)*9,178+breath)
	eyes[6].rotation = -PI*.5+sin(time*.33)*.03
	eyes[6].flex(time,0)
	mounts.clear()
	rest_tips.clear()
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var anchor := Vector2(side*245,150+breath)
		var rest_tip := Vector2(side*330,545+breath)
		var tip := rest_tip
		var tension := 0.0
		for attack in lunges:
			if attack.paw != i: continue
			var target: Vector2 = to_local(attack.target)
			var local: float = time-attack.start
			if local < Cfg.LUNGE_WARNING:
				tension = smoothstep(0,Cfg.LUNGE_WARNING,local)
				tip = rest_tip+Vector2(-side*16,-48)*tension
			elif local < Cfg.LUNGE_WARNING+Cfg.LUNGE_TRAVEL:
				var blend := smoothstep(0,Cfg.LUNGE_TRAVEL,local-Cfg.LUNGE_WARNING)
				tension = lerpf(1.0,.2,blend)
				tip = (rest_tip+Vector2(-side*16,-48)).lerp(target,blend)
			elif local < Cfg.LUNGE_WARNING+Cfg.LUNGE_TRAVEL+Cfg.LUNGE_HOLD:
				tip = target
			else:
				var ret := local-Cfg.LUNGE_WARNING-Cfg.LUNGE_TRAVEL-Cfg.LUNGE_HOLD
				var blend := smoothstep(0,Cfg.LUNGE_RETURN,ret)
				tip = target.lerp(rest_tip,blend)+Vector2(side*48,-30)*sin(PI*blend)
				tension = sin(blend*PI)*side*.6
		var direction := (tip-anchor).normalized()
		paws[i].position = tip-direction*paws[i].part_size.y*.34
		paws[i].rotation = direction.angle()-PI*.5
		paws[i].flex(time-i*.13,i, tension)
		cable(anchor,paws[i].position-direction*paws[i].part_size.y*.38,time+i*2)
		var mount: Node2D = pieces["SpearMount%d"%i]
		mount.position = Vector2(side*435,350+breath)+Vector2(0,recoil*side)
		mount.rotation = -side*.18+sin(time*.6-i)*.025
		mount.flex(time,i)
		mounts.append(to_global(mount.position+Vector2(-side*32,35)))
		rest_tips.append(to_global(tip))
	queue_redraw()

func paw_tip(index: int) -> Vector2:
	return rest_tips[index]

func cable(from: Vector2, to: Vector2, time: float) -> void:
	var points := PackedVector2Array()
	var normal := (to-from).orthogonal().normalized()
	for i in range(19):
		var blend := i/18.0
		points.append(from.lerp(to,blend)+normal*sin(blend*PI)*(18+sin(time*.8)*5))
	cables.append(points)

func _draw() -> void:
	for points in cables:
		draw_polyline(points,Color("#111111"),9,true)
		draw_polyline(points,Color("#747474"),6,true)
		draw_polyline(points,Color("#d9d9d9"),1.3,true)
		var braid := points.duplicate()
		for i in braid.size():
			braid[i] += Vector2(sin(i*.95+clock*.5)*2.0,0)
		draw_polyline(braid,Color("#bebebe"),1,true)
