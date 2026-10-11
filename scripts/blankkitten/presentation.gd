extends Node2D
const Cue = preload("res://scripts/blankkitten/timeline.gd")
const ART := [preload("res://assets/enironment/bosses/boss3-BlankKitten/normalKitten-transparent.png"), preload("res://assets/enironment/bosses/boss3-BlankKitten/kittenstage.1-transparent.png"), preload("res://assets/enironment/bosses/boss3-BlankKitten/kittenstage2-transparent.png"), preload("res://assets/enironment/bosses/boss3-BlankKitten/kittenstage3-transparent.png")]
@export var look: Resource = preload("res://resources/blankkitten/look.tres")
## Optional native Godot video override: Ogg Theora .ogv, muted and looped.
@export var fire_video: VideoStream
var battle: Node
var spin_pivot: Node2D
var bob_pivot: Node2D
var sprite: Sprite2D
var title: Control
var fire: ColorRect
var video: VideoStreamPlayer
var fire_material: ShaderMaterial
var clock := 0.0
var distortion := 0
var fire_strength := 0.0
var spin_direction := 1
var outline_id := 0

func _ready() -> void:
	battle = get_parent()
	z_index = -1
	fire = ColorRect.new()
	fire.name = "ProceduralFire"
	fire.z_index = -1
	fire.size = Vector2(540,900)
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_material = ShaderMaterial.new()
	fire_material.shader = preload("res://shaders/blankkitten_fire.gdshader")
	fire.material = fire_material
	add_child(fire)
	if fire_video != null:
		video = VideoStreamPlayer.new()
		video.name = "FireVideo"
		video.z_index = -1
		video.stream = fire_video
		video.expand = true
		video.size = Vector2(540,900)
		video.volume = 0.0
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(video)
		video.finished.connect(video.play)
	spin_pivot = Node2D.new()
	spin_pivot.name = "SpinPivot"
	spin_pivot.position = Vector2(270,230)
	add_child(spin_pivot)
	bob_pivot = Node2D.new()
	bob_pivot.name = "BeatBobPivot"
	spin_pivot.add_child(bob_pivot)
	sprite = Sprite2D.new()
	sprite.name = "BlankKittenArtwork"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*0.36
	bob_pivot.add_child(sprite)
	# The outline is drawn once by this persistent canvas, never replaced.
	outline_id = get_instance_id()

func attach_title(root: Control) -> void:
	title = Control.new()
	title.name = "ShowdownTitle"
	title.set_script(preload("res://scripts/ui/cinematic_title.gd"))
	title.look = look
	root.add_child(title)

func update_clock(time: float) -> void:
	clock = time
	distortion = Cue.distortion_at(clock)
	sprite.texture = ART[distortion]
	fire_strength = Cue.fire_at(clock)
	fire_material.set_shader_parameter("clock",clock)
	fire_material.set_shader_parameter("intensity",fire_strength)
	fire.visible = fire_strength > 0 and video == null
	if video != null:
		video.modulate.a = fire_strength*0.6
		video.visible = fire_strength > 0
		if fire_strength > 0 and not video.is_playing():
			video.play()
		elif fire_strength <= 0 and video.is_playing():
			video.stop()
	var section := Cue.stage_at(clock)
	var intensity: float = [0.55,0.8,1.25,0.5,1.45,1.65,2.0,0.5][section]
	var settle := 1-smoothstep(130.28,Cue.END,clock) if section == 7 else 1.0
	intensity *= settle
	var beat := clock / Cue.BEAT * TAU
	# Independent nested pivots prevent a spin tween from overriding the bob.
	bob_pivot.position.y = sin(beat)*3.2*intensity
	bob_pivot.rotation = sin(beat*0.5)*deg_to_rad(3+minf(intensity,2))*settle
	var target := Cue.morph_at(clock)
	if target >= 0:
		var progress := clampf((clock-(Cue.STARTS[target]-Cue.MORPH))/Cue.MORPH,0,1)
		spin_direction = 1 if target%2 == 1 else -1
		spin_pivot.rotation = spin_direction*TAU*smoothstep(0,1,progress)
	else:
		spin_pivot.rotation = 0 # 2π is the same visual orientation at the join.
	if title != null:
		title.update_clock(clock)
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = battle.arena_rect
	var transition := Cue.morph_at(clock)
	var tint := Color("#F1EEF7")
	var glow := 0.08+fire_strength*0.04
	draw_rect(rect.grow(5),Color(tint,glow),false,4,true)
	draw_rect(rect,Color(0.07,0.075,0.095,0.94))
	# Interior ruling/platforms fade before morphing; the outline never fades.
	var interior := 1.0
	if transition >= 0:
		interior = 1-smoothstep(0,0.25,clock-(Cue.STARTS[transition]-Cue.MORPH))
	for y in range(int(rect.position.y)+30,int(rect.end.y),30):
		draw_line(Vector2(rect.position.x+1,y),Vector2(rect.end.x-1,y),Color(0.75,0.72,0.85,0.04*interior),1)
	if Cue.GRAVITY[battle.stage]:
		draw_line(Vector2(rect.position.x+1,rect.end.y-1),rect.end-Vector2(1,1),Color(tint,0.3*interior),3)
	draw_rect(rect,tint,false,2.0,true)
	for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		draw_circle(corner,2.2,tint)
