extends Node2D
# One bounded canvas for transient effects; no physics bodies or per-spark nodes.
const MAX_PARTICLES := 256
const MAX_GHOSTS := 12
var particles: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var graze_count := 0
var sound_cooldown := 0.0
var sound: AudioStreamPlayer
var ghost_canvas: Node2D
var aura_canvas: Node2D

func _ready() -> void:
	z_index = 8
	ghost_canvas = Node2D.new()
	ghost_canvas.set_script(preload("res://scripts/boss2/afterimages.gd"))
	ghost_canvas.z_index = -3
	get_parent().add_child(ghost_canvas)
	ghost_canvas.effects = self
	aura_canvas = Node2D.new()
	aura_canvas.set_script(preload("res://scripts/boss2/aura.gd"))
	aura_canvas.z_index = -4
	get_parent().add_child(aura_canvas)
	# A quiet, short synthesized chirp; no imported or invented artwork/audio files.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(882*2)
	for i in range(882):
		var t := i/22050.0
		var envelope := sin(PI*i/882.0) * (1-i/882.0)
		data.encode_s16(i*2,int(sin(TAU*(2100*t-9000*t*t))*envelope*1800))
	wav.data = data
	sound = AudioStreamPlayer.new()
	sound.stream = wav
	sound.volume_db = -18
	add_child(sound)

func burst(point: Vector2, tint: Color, count: int = 6, force: float = 100, lifetime: float = 0.32, shards: bool = false) -> void:
	for i in range(count):
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var angle := i*TAU/count+randf_range(-0.3,0.3)
		particles.append({"point":point,"velocity":Vector2.RIGHT.rotated(angle)*force*randf_range(0.5,1.3),"age":0.0,"life":lifetime,"tint":tint,"shard":shards,"spin":angle})

func dissolve(point: Vector2, tint: Color, radius: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	particles.append({"point":point,"velocity":Vector2.ZERO,"age":0.0,"life":0.20,"tint":tint,"shard":false,"spin":0.0,"dissolve_radius":radius})

func afterimage(sprite: Sprite2D) -> void:
	if ghosts.size() >= MAX_GHOSTS:
		ghosts.pop_front()
	ghosts.append({"texture":sprite.texture,"position":sprite.global_position,"scale":sprite.global_scale,"age":0.0})

func graze(point: Vector2, tint: Color) -> void:
	graze_count += 1
	burst(point,tint.lightened(0.7),4,65,0.2)
	if sound_cooldown <= 0:
		sound_cooldown = 0.08
		sound.play()

func clear() -> void:
	particles.clear()
	ghosts.clear()
	sound.stop()
	queue_redraw()
	ghost_canvas.queue_redraw()

func _process(delta: float) -> void:
	sound_cooldown = maxf(0,sound_cooldown-delta)
	for i in range(particles.size()-1,-1,-1):
		var p := particles[i]
		p.age += delta
		p.point += p.velocity*delta
		p.velocity *= exp(-3*delta)
		if p.age >= p.life:
			particles.remove_at(i)
	for i in range(ghosts.size()-1,-1,-1):
		ghosts[i].age += delta
		if ghosts[i].age >= 0.24:
			ghosts.remove_at(i)
	queue_redraw()
	ghost_canvas.queue_redraw()
	aura_canvas.queue_redraw()

func _draw() -> void:
	for p in particles:
		draw_set_transform(Vector2.ZERO)
		var fade: float = 1-p.age/p.life
		if p.has("dissolve_radius"):
			draw_arc(p.point,p.dissolve_radius*(1+(1-fade)*0.6),0,TAU,16,Color(p.tint,fade*fade),1.2,true)
		elif p.shard:
			preload("res://scripts/ui/human_effects.gd").draw_impact(self,p.point,p.age,p.life,9,p.tint)
			draw_set_transform(p.point,p.spin+p.age*6)
			draw_colored_polygon(PackedVector2Array([Vector2(-3,-2),Vector2(4,0),Vector2(-1,4)]),Color(p.tint,fade))
		else:
			draw_line(p.point,p.point-p.velocity.normalized()*5,Color(p.tint,fade),1.2,true)
	draw_set_transform(Vector2.ZERO)
