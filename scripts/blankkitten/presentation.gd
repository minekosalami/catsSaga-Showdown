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
var background_container: SubViewportContainer
var background_viewport: SubViewport
var veil: ColorRect
var veil_material: ShaderMaterial
var smoke: ColorRect
var smoke_material: ShaderMaterial
var art_material: ShaderMaterial
var smoke_strength := 0.0
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
	# Soft atmospheric layers render at half resolution; artwork, hazards and
	# UI remain native 540×900. Reduced FX uses quarter resolution.
	background_container = SubViewportContainer.new()
	background_container.name = "AtmosphereComposite"
	background_container.z_index = -3
	background_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(background_container)
	background_viewport = SubViewport.new()
	background_viewport.name = "AtmosphereViewport"
	background_viewport.size = Vector2i(270,450)
	background_viewport.disable_3d = true
	background_viewport.gui_disable_input = true
	background_viewport.world_2d = World2D.new()
	background_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	background_container.add_child(background_viewport)
	smoke = ColorRect.new()
	smoke.name = "LayeredAtmosphere"
	smoke.z_index = -3
	smoke.size = Vector2(540,900)
	smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smoke_material = ShaderMaterial.new()
	smoke_material.shader = preload("res://shaders/blankkitten_smoke.gdshader")
	smoke.material = smoke_material
	background_viewport.add_child(smoke)
	fire = ColorRect.new()
	fire.name = "ProceduralFire"
	fire.z_index = -1
	fire.size = Vector2(540,900)
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_material = ShaderMaterial.new()
	fire_material.shader = preload("res://shaders/blankkitten_fire.gdshader")
	fire.material = fire_material
	background_viewport.add_child(fire)
	if fire_video != null:
		video = VideoStreamPlayer.new()
		video.name = "FireVideo"
		video.z_index = -1
		video.stream = fire_video
		video.expand = true
		video.size = Vector2(540,900)
		video.volume = 0.0
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_viewport.add_child(video)
		video.finished.connect(video.play)
	veil = ColorRect.new()
	veil.name = "ForegroundSmoke"
	veil.size = Vector2(540,900)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_material = ShaderMaterial.new()
	veil_material.shader = preload("res://shaders/blankkitten_smoke.gdshader")
	veil_material.set_shader_parameter("foreground",true)
	veil.material = veil_material
	background_viewport.add_child(veil)
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
	art_material = ShaderMaterial.new()
	art_material.shader = preload("res://shaders/blankkitten_art.gdshader")
	sprite.material = art_material
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
	var target_size := Vector2i(135,225) if battle.reduced_effects else Vector2i(270,450)
	if background_viewport.size != target_size: background_viewport.size = target_size
	background_container.size = Vector2(target_size)
	background_container.scale = Vector2.ONE*(540.0/target_size.x)
	for layer in [smoke,fire,veil]: layer.size = Vector2(target_size)
	if video != null: video.size = Vector2(target_size)
	distortion = Cue.distortion_at(clock)
	sprite.texture = ART[distortion]
	fire_strength = Cue.fire_at(clock)
	fire_material.set_shader_parameter("clock",clock)
	fire_material.set_shader_parameter("intensity",fire_strength)
	var strength := .35 if battle.reduced_effects else 1.0
	fire_material.set_shader_parameter("strength",strength)
	var resolution := smoothstep(130.28,Cue.END,clock)
	smoke_strength = (.15+distortion*.06+fire_strength*.45)*(1-resolution*.85)
	smoke_material.set_shader_parameter("clock",clock)
	smoke_material.set_shader_parameter("distortion",float(distortion))
	smoke_material.set_shader_parameter("inferno",fire_strength)
	smoke_material.set_shader_parameter("resolution",resolution)
	smoke_material.set_shader_parameter("strength",strength)
	for property in ["clock","distortion","inferno","resolution","strength"]:
		veil_material.set_shader_parameter(property,smoke_material.get_shader_parameter(property))
	var arena: Rect2 = battle.arena_rect
	veil_material.set_shader_parameter("arena",Vector4(arena.position.x,arena.position.y,arena.size.x,arena.size.y))
	art_material.set_shader_parameter("clock",clock)
	art_material.set_shader_parameter("corruption",distortion*(1-resolution))
	art_material.set_shader_parameter("intensity",strength)
	art_material.set_shader_parameter("flash",(1-smoothstep(102.85,103.07,clock)) if clock >= 102.85 else 0)
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
		title.label.text = "Sequence: BlankKitten"
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = battle.arena_rect
	var transition := Cue.morph_at(clock)
	var beat := 1-smoothstep(0,.23,fposmod(clock,Cue.MEASURE))
	var strength := .35 if battle.reduced_effects else 1.0
	var resolution := smoothstep(130.28,Cue.END,clock)
	var tint := Color("#EAE4F3").lerp(Color("#FFADB4"),fire_strength*.25)
	# Technical ornament stays outside the gameplay silhouette.
	for side in [-1,1]:
		var x: float = 270+side*246
		draw_line(Vector2(x,135),Vector2(x,350),Color(tint,.2),1,true)
		for i in 12:
			var length := 4+(i%3)*3
			draw_line(Vector2(x,145+i*16),Vector2(x-side*length,145+i*16),Color(tint,.22),1,true)
	var halo := Vector2(270,230)
	for i in 3:
		draw_arc(halo,110+i*12,clock*.06+i,clock*.06+i+PI*1.35,90,Color(tint,(.04+beat*.025)*strength),1,true)
	# Arena interior is deliberately opaque enough to suppress background smoke.
	draw_rect(rect,Color(.027,.025,.037,.94))
	for y in range(int(rect.position.y)+15,int(rect.end.y),15):
		draw_line(Vector2(rect.position.x+1,y),Vector2(rect.end.x-1,y),Color(.6,.53,.68,.035),1)
	for x in range(int(rect.position.x)+16,int(rect.end.x),24):
		for y in range(int(rect.position.y)+16,int(rect.end.y),24):
			draw_circle(Vector2(x,y),.65,Color(.6,.55,.7,.06))
	for i in range(3,0,-1):
		draw_rect(rect.grow(i*2+2),Color(tint,(.035+beat*.015)*strength),false,2,true)
	draw_rect(rect,tint,false,2,true) # inner surface is exactly one pixel inward
	draw_rect(rect.grow(4),Color(tint,.35+beat*.12*strength),false,1,true)
	for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
		var direction := Vector2(1 if corner.x < rect.get_center().x else -1,1 if corner.y < rect.get_center().y else -1)
		draw_line(corner,corner+Vector2(14*direction.x,0),Color.WHITE,2,true)
		draw_line(corner,corner+Vector2(0,14*direction.y),Color.WHITE,2,true)
	# Embers derive analytically from soundtrack time: no particle/node backlog.
	for i in (18 if battle.reduced_effects else 60):
		var progress := fposmod(clock*(.12+(i%5)*.014)+i*.618,1)
		var point := Vector2(fposmod(i*97.0+sin(clock*.7+i)*19,540),900-progress*850)
		if rect.grow(9).has_point(point): continue
		var alpha := sin(progress*PI)*fire_strength*.7
		draw_line(point,point+Vector2(sin(i+clock),3+(i%3)),Color(1,.49,.16,alpha),1.2,true)
	if clock >= 102.85 and clock < 103.15:
		var flash := (1-smoothstep(102.85,103.15,clock))*.07*strength
		# Controlled flash restricted above the arena; the first lane stays readable.
		draw_rect(Rect2(0,100,540,260),Color(1,.75,.6,flash))
