extends Node2D
## Bounded reusable effects canvas and four cached quiet procedural sound voices.
const MAX_PARTICLES := 192
var battle: Node
var particles: Array[Dictionary] = []
var cracks: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var sound_until := -1.0
var shake_start := -10.0
var shake_amount := 0.0
var death_age := -1.0
var time := 0.0
var graze_count := 0
var crackle_beat := -1

func _ready() -> void:
	battle = get_parent()
	z_index = 3
	for kind in ["impact","bounce","laser","hit","morph","warning","graze","beam","glitch","fire"]:
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var samples := 3307 if kind in ["impact","morph","beam"] else 1764
		var bytes := PackedByteArray()
		bytes.resize(samples*2)
		var frequency: float = {"impact":80,"bounce":145,"laser":620,"hit":310,"morph":170,"warning":720,"graze":1550,"beam":240,"glitch":400,"fire":65}[kind]
		for i in samples:
			var t := i/22050.0
			var phase := float(i)/samples
			var noise := sin(i*127.1)*.3 if kind in ["impact","glitch","fire"] else 0.0
			var wave := sin(TAU*(frequency*t+frequency*t*t*2))+noise
			bytes.encode_s16(i*2,int(wave*sin(PI*phase)*pow(1-phase,2)*1900))
		stream.data = bytes
		sounds[kind] = stream
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -19
		add_child(voice)
		voices.append(voice)

func cue(kind: String, clock: float) -> void:
	if clock < sound_until: return
	sound_until = clock+.12
	for voice in voices:
		if not voice.playing:
			voice.volume_db = -29 if kind == "fire" else -19
			voice.stream = sounds[kind]
			voice.play()
			break

func burst(point: Vector2, tint: Color, count: int, clock: float, life := .6, smoke := false) -> void:
	for i in (maxi(2,count/3) if battle.reduced_effects else count):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		var angle := i*2.39996+clock
		var force := 35.0 if smoke else 95.0+float(i%5)*20
		particles.append({"point":point,"velocity":Vector2.RIGHT.rotated(angle)*force+Vector2(0,-35),"start":clock,"life":life,"tint":tint,"smoke":smoke,"spin":angle})

func impact(point: Vector2, strength: float, clock: float) -> void:
	cue("impact",clock)
	shake_start = clock
	shake_amount = 2.0*strength
	burst(point,Color("#FFA778"),8,clock,.55)
	burst(point,Color("#827685"),4,clock,.8,true)
	cracks.append({"point":point,"start":clock})
	if cracks.size() > 20: cracks.pop_front()

func bounce(point: Vector2, clock: float) -> void:
	cue("bounce",clock)
	burst(point,Color("#FFC16C"),12,clock)
	shake_start = clock
	shake_amount = 1.3

func graze(point: Vector2, clock: float) -> void:
	graze_count += 1
	cue("graze",clock)
	burst(point,Color.from_hsv(fposmod(clock*.65,1),.8,1),6,clock,.22)

func hit(point: Vector2, clock: float) -> void:
	cue("hit",clock)
	burst(point,Color.WHITE,12,clock,.35)
	shake_start = clock
	shake_amount = 2.5

func die(point: Vector2) -> void:
	clear()
	death_age = 0
	burst(point,Color.WHITE,30,0,.65)
	for i in particles.size(): particles[i].tint = Color.from_hsv(float(i)/particles.size(),.8,1)
	cue("hit",0)

func clear() -> void:
	particles.clear()
	cracks.clear()
	death_age = -1
	shake_start = -10
	crackle_beat = -1
	sound_until = -1
	battle.position = Vector2.ZERO
	for voice in voices: voice.stop()

func update_clock(clock: float) -> void:
	time = clock
	if death_age < 0 and not battle.game_over and not battle.victory_started and (battle.stage == 2 or battle.presentation.fire_strength > .25):
		var beat := int(clock/(60.0/140*4))
		if beat != crackle_beat:
			crackle_beat = beat
			cue("fire",clock)
	particles = particles.filter(func(p): return time-p.start < p.life and time >= p.start)
	cracks = cracks.filter(func(p): return time-p.start < 1.3 and time >= p.start)
	var fade := 1-smoothstep(0,.2,time-shake_start)
	var amount := 0.0 if battle.reduced_effects else shake_amount*fade
	battle.position = Vector2(sin(time*93),cos(time*117))*amount
	queue_redraw()

func _process(delta: float) -> void:
	if death_age >= 0:
		death_age += delta
		update_clock(death_age)
		if death_age >= .7:
			death_age = -1
			battle.ui.show_result(false,battle.audio_error)

func _draw() -> void:
	for p in particles:
		var age: float = time-p.start
		var fade: float = 1-age/p.life
		var point: Vector2 = p.point+p.velocity*age+Vector2(0,65)*age*age
		if p.smoke:
			var extent := 16+age*24
			draw_texture_rect(preload("res://scripts/ui/human_effects.gd").frame("smoke",int(age/p.life*6)),Rect2(point-Vector2.ONE*extent*.5,Vector2.ONE*extent),false,Color(p.tint,fade*.22))
		else:
			draw_set_transform(point.round(),p.spin+age*4)
			draw_texture_rect(preload("res://scripts/ui/human_effects.gd").frame("sparkle",int(age*14)),Rect2(-4,-4,8,8),false,Color(p.tint,fade))
	draw_set_transform(Vector2.ZERO)
	for crack in cracks:
		var age: float = time-crack.start
		if age<.4:
			# Leave the actual safe corridor unobscured between adjacent impacts.
			var lane_width: float = battle.arena_rect.size.x/battle.hazards.LANES
			preload("res://scripts/ui/human_effects.gd").draw_impact(self,crack.point,age,.4,minf(12 if battle.reduced_effects else 16,lane_width*.25),Color("#FFA778"))
		if age < .22:
			for i in range(3,0,-1): draw_circle(crack.point,12+i*14,Color(1,.46,.36,(1-age/.22)*.025))
		var fade := 1-smoothstep(.25,1.3,time-crack.start)
		for side in [-1,1]:
			var p: Vector2 = crack.point
			draw_polyline(PackedVector2Array([p,p+Vector2(8*side,-4),p+Vector2(17*side,-2),p+Vector2(29*side,-8)]),Color(1,.45,.56,fade*.65),1,true)
