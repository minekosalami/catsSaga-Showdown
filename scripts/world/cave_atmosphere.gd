extends Node2D
## A single following light, restrained haze/dust, and quiet native ambient audio.
const Plan = preload("res://scripts/world/cave_layout.gd")
var player: Node2D
var lamp: PointLight2D
var overlay: CanvasLayer
var dust: Node2D
var haze_material: ShaderMaterial
var bed: AudioStreamPlayer
var drip: AudioStreamPlayer
var echo: AudioStreamPlayer
var clock := 0.0
var next_drip := 3.0
var next_echo := 12.0
var fade_started := false
var has_been_revealed := false
class Dust extends Node2D:
	var clock := 0.0
	func _draw() -> void:
		var dimensions := get_viewport_rect().size
		for i in 26:
			var point := Vector2(fposmod(i*97.0+sin(clock*.12+i)*18,dimensions.x),fposmod(i*137.0-clock*(1+i%3),dimensions.y))
			draw_rect(Rect2(point,Vector2.ONE*2),Color(.75,.8,.88,.04+.04*sin(clock*.4+i)))
func sound(kind: String) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 22050
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var count := 88200 if kind == "bed" else 22050
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/22050
		var value := .35*sin(TAU*34*t)+.17*sin(TAU*51*t) if kind == "bed" else 0.0
		if kind == "drip":
			for delay in [0.0,.12,.28]:
				var age: float = t-delay
				if age >= 0: value += sin(TAU*(1300*age-1700*age*age))*exp(-age*23)*(.8 if delay == 0 else .22)
		if kind == "echo": value = sin(TAU*(112*t+17*t*t))*sin(PI*t)*exp(-t*3)*.4
		bytes.encode_s16(i*2,int(value*1800))
	wav.data = bytes
	if kind == "bed":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav
func _ready() -> void:
	var darkness := CanvasModulate.new()
	darkness.name = "UndergroundAmbientLight"
	darkness.color = Color(.68,.69,.79)
	add_child(darkness)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,.75),Color(1,1,1,.15),Color(1,1,1,0)])
	gradient.offsets = PackedFloat32Array([0,.4,1])
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(.5,0)
	texture.gradient = gradient
	lamp = PointLight2D.new()
	lamp.texture = texture
	lamp.texture_scale = 4.0
	lamp.energy = .6
	lamp.color = Color(.84,.91,1)
	lamp.shadow_enabled = false
	add_child(lamp)
	overlay = CanvasLayer.new()
	overlay.layer = 0
	add_child(overlay)
	var haze := ColorRect.new()
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(haze)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze_material = ShaderMaterial.new()
	haze_material.shader = preload("res://shaders/cave_haze.gdshader")
	haze.material = haze_material
	dust = Dust.new()
	overlay.add_child(dust)
	for kind in ["bed","drip","echo"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = sound(kind)
		audio.bus = "Overworld"
		audio.volume_db = -28 if kind != "echo" else -32
		add_child(audio)
		if kind == "bed": bed = audio
		elif kind == "drip": drip = audio
		else: echo = audio
	bed.play()
func _process(delta: float) -> void:
	if player == null: player = get_parent().get_parent().get_node_or_null("Explorer")
	if player != null: lamp.position = player.position
	overlay.visible = get_parent().visible
	clock += delta
	haze_material.set_shader_parameter("clock",clock)
	dust.clock = clock
	dust.queue_redraw()
	if not Session.busy: has_been_revealed = true
	if Session.busy and has_been_revealed and not fade_started:
		fade_started = true
		for voice in [bed,drip,echo]: create_tween().tween_property(voice,"volume_db",-60.0,.25)
	if not Session.busy:
		if clock >= next_drip:
			next_drip = clock+5.5+fposmod(clock*1.618,3.0)
			drip.pitch_scale = .85+fposmod(clock*.1,.25)
			drip.play()
		if clock >= next_echo:
			next_echo = clock+18+fposmod(clock*2.3,7)
			echo.play()
