extends Node2D
## View-limited environmental geometry and existing human leaf texture. No art
## files are generated. This node exists only in exploration, below dialogue/HUD.
const LEAF=preload("res://assets/overhaul_human/ninja/leaf_00.png")
var clock =0.0
var weather: Node
var modulation: CanvasModulate
var canopy: ShaderMaterial
var region ="entrance"
var bounds =Rect2()
var drops: Array[Vector2]=[]
var motes: Array[Vector3]=[]
var splash_audio: AudioStreamPlayer2D
var splash_wait =2.0
var water_sample_wait =0.0
var bridge_audio: AudioStreamPlayer2D
var bridge_wait =0.0
var water_surface: TileMapLayer
var understory: TileMapLayer
var surface_layers: Array[TileMapLayer]=[]
func _ready() -> void:
	z_index=6
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	region=get_parent().region_id
	weather=Session.weather
	water_surface=get_parent().get_node("WaterSurface")
	understory=get_parent().get_node("Understory")
	for label in ["Bridges","Water"]:surface_layers.append(get_parent().get_node(label))
	modulation=CanvasModulate.new();add_child(modulation)
	canopy=ShaderMaterial.new();canopy.shader=preload("res://shaders/forest_canopy_wind.gdshader")
	for tree in get_tree().get_nodes_in_group("journey_trees"):
		if get_parent().is_ancestor_of(tree):tree.get_node("Sprite2D").material=canopy
	# Parent _ready runs before its tree children? Defer one pass for baked trees.
	apply_canopy.call_deferred()
	var rng =RandomNumberGenerator.new();rng.seed=hash(region)
	for i in 160:drops.append(Vector2(rng.randf(),rng.randf()))
	for i in 42:motes.append(Vector3(rng.randf(),rng.randf(),rng.randf()*TAU))
	splash_audio=AudioStreamPlayer2D.new()
	splash_audio.stream=preload("res://assets/ambience_human/drippingwater_drip_a.ogg")
	splash_audio.bus="Ambience";splash_audio.max_distance=450;splash_audio.volume_db=-26
	add_child(splash_audio)
	bridge_audio=AudioStreamPlayer2D.new()
	bridge_audio.stream=load("res://assets/weather_human/wood_creak.ogg")
	bridge_audio.bus="Ambience";bridge_audio.max_distance=350;bridge_audio.volume_db=-30
	add_child(bridge_audio)
func apply_canopy() -> void:
	for tree in get_tree().get_nodes_in_group("journey_trees"):
		if get_parent().is_ancestor_of(tree):tree.get_node("Sprite2D").material=canopy
func _process(delta: float) -> void:
	var world =get_parent().get_parent()
	if world.get("player")==null:return # Editor/map-cache render stays stable.
	var visuals=get_node("/root/VisualSettings")
	var motion: float=visuals.motion*(.35 if visuals.reduced else 1.0)
	clock+=delta*motion
	var camera:Camera2D=world.player.get_node("Camera2D")
	var size:Vector2=get_viewport_rect().size/camera.zoom
	bounds=Rect2(camera.get_screen_center_position()-size*.5,size)
	var base:Color={"entrance":Color(1,.98,.91),"deep_forest":Color(.77,.84,.85),"bart_area":Color(.97,.88,.99),"flooded_forest":Color(.78,.88,.96)}[region]
	modulation.color=base.lerp(base*.76,weather.cloud*.6)
	canopy.set_shader_parameter("wind",weather.wind)
	canopy.set_shader_parameter("motion",motion)
	understory.material.set_shader_parameter("wind_strength",weather.wind)
	understory.material.set_shader_parameter("motion",motion)
	# Water is the hidden collision footprint. WaterSurface owns visible ripples.
	water_surface.material.set_shader_parameter("rain_strength",weather.rain)
	water_surface.material.set_shader_parameter("motion",motion)
	water_sample_wait-=delta
	if water_sample_wait<=0:
		water_sample_wait=.5
		var proximity=0.0
		for offset in [Vector2(96,0),Vector2(-96,0),Vector2(0,96),Vector2(0,-96),Vector2(0,192),Vector2(0,-192)]:
			if surface(world.player.position+offset)==1:proximity=maxf(proximity,1.0 if offset.length()<150 else .45)
		get_node("/root/Ambience").water_proximity=proximity
	bridge_wait-=delta
	if surface(world.player.position)==2 and world.player.velocity.length()>20 and bridge_wait<=0 and get_node("/root/Ambience").enabled:
		bridge_wait=4.0
		bridge_audio.position=world.player.position
		bridge_audio.play()
	splash_wait-=delta
	if weather.rain>.2 and splash_wait<=0 and get_node("/root/Ambience").enabled:
		splash_wait=2.2
		var candidate:Vector2=world.player.position+Vector2(100*sin(clock),80*cos(clock))
		if surface(candidate)>0:
			splash_audio.position=candidate
			splash_audio.play()
	queue_redraw()
func surface(point: Vector2) -> int:
	for i in surface_layers.size():
		var layer:=surface_layers[i]
		if layer.get_cell_source_id(layer.local_to_map(layer.to_local(get_parent().to_global(point))))>=0:return 2-i
	return 0
func _draw() -> void:
	if bounds.size==Vector2.ZERO:return
	var amount:float=weather.rain*(1 if region=="flooded_forest" else .75)
	var reduced:bool=get_node("/root/VisualSettings").reduced
	if region=="entrance" and weather.cloud<.7:
		for i in 3:
			var origin =bounds.position+Vector2(bounds.size.x*(.1+i*.38)+sin(clock*.06+i)*24,-60)
			draw_colored_polygon(PackedVector2Array([origin,origin+Vector2(32,0),origin+Vector2(210,bounds.size.y+60),origin+Vector2(130,bounds.size.y+60)]),Color(1,.91,.64,.025*(1-weather.cloud)))
	if region=="deep_forest":
		var shop=preload("res://scripts/story/world_content.gd").SHOP_POSITION
		if bounds.grow(140).has_point(shop):
			for ring in 4:draw_circle(shop+Vector2(0,-30),140-ring*25,Color(1,.76,.42,.012))
	for i in motes.size():
		var m =motes[i]
		var point =bounds.position+Vector2(fposmod(m.x+clock*.008*weather.wind,1)*bounds.size.x,fposmod(m.y+clock*.009,1)*bounds.size.y)
		if i%3==0:
			draw_texture_rect_region(LEAF,Rect2(point,Vector2(10,12)),Rect2(80,108,36,40),Color(1,1,1,.38))
		elif region=="entrance" and i%5==0: # small procedural wing geometry
			var flap =1+absf(sin(clock*5+m.z))*2
			draw_circle(point+Vector2(-flap,0),2,Color(.95,.85,.65,.65))
			draw_circle(point+Vector2(flap,0),2,Color(.95,.85,.65,.65))
		elif region in ["deep_forest","bart_area"]:
			draw_circle(point,1.2,Color(.95,.88,1,.15+.18*sin(clock+m.z)))
	if region=="flooded_forest" or weather.cloud>.6:
		for i in 4:
			var y =bounds.position.y+fposmod(i*.29+sin(clock*.025+i)*.03,1)*bounds.size.y
			draw_rect(Rect2(bounds.position.x,y,bounds.size.x,18),Color(.7,.85,.9,.018 if reduced else .035))
	for i in int(lerpf(0,80 if reduced else 160,amount)):
		var drop =drops[i]
		var phase =fposmod(drop.y+clock*(.8+weather.wind*.2),1)
		var point =bounds.position+Vector2(fposmod(drop.x-clock*weather.wind*.025,1)*bounds.size.x,phase*bounds.size.y)
		draw_line(point,point+Vector2(-3-weather.wind*5,12),Color(.65,.82,.98,.22),1)
		if i%5==0 and phase>.82:
			var kind =surface(point)
			if kind==1:draw_arc(point,2+(phase-.82)*18,0,TAU,12,Color(.7,.9,1,(1-phase)*1.5),1)
			elif kind==2:
				draw_line(point-Vector2(3,2),point,Color(.8,.8,.7,.3),1)
			else:draw_circle(point,1,Color(.65,.8,.65,.15))
