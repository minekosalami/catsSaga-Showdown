extends Node
## Persistent sequence owner: the forest scene can be freed during travel.
const Plan=preload("res://scripts/wonderland/layout.gd")
const Trap=preload("res://scripts/story/ambush_trap.gd")
const CatActor=preload("res://scripts/story/cat_actor.gd")
const Navigator=preload("res://scripts/story/ambush_navigation.gd")
const Catalog=preload("res://scripts/encounters/catalog.gd")
const SONG="res://assets/soundtrack/Song that plays when you get ATTACKED! - 009.mp3"
const INTRO=[
	"Welcome to Wonerland! Where all of your dreams come true. Not really.",
	"You owe me one after how I saved you back there...",
	"Stay here for a while. But one piece of advice:",
	"Don't piss off the Princess.","See ya!"]
var world: Node
var stage: Node2D
var hero: Sprite2D
var smoki: Sprite2D
var enemies: Array[Sprite2D]=[]
var music: AudioStreamPlayer
var phase := "idle"
var spoken: Array[String]=[]
var landed := 0
var original_zoom := Vector2.ONE
var origin:=Vector2.ZERO
var navigation:RefCounted
var formation:Array[Vector2]=[]
var saved_camera_limits:=Rect2()
var camera_was_top_level:=false
var actor_count:=0
var canopy_alpha:Dictionary={}
static func install(scene: Node) -> void:
	if Session.area_id=="flooded_forest" and Session.story_flags.get("boss2_defeated",false) and not Session.story_flags.get("wonderland_arrived",false):
		var trap=Trap.new();trap.name="AmbushTrap";trap.position=Trap.POINT
		scene.map.add_child(trap)
	elif Plan.regions().has(Session.area_id) and Session.story_flags.get("wonderland_arrived",false) and not Session.story_flags.get("wonderland_intro_completed",false) and not Session.story_sequence_active:
		var sequence=load("res://scripts/story/ambush.gd").new()
		Session.add_child(sequence)
		sequence.resume.call_deferred(scene)
func resume(scene: Node) -> void:
	while Session.busy:await get_tree().process_frame
	world=scene
	lock()
	await arrival(false)
func lock() -> void:
	process_priority=100
	Session.story_sequence_active=true
	Session.busy=true
	world.player.movement_locked=true
	world.player.velocity=Vector2.ZERO
	world.hide_interaction()
func restore_canopies() -> void:
	for art in canopy_alpha:
		if is_instance_valid(art):art.self_modulate.a=canopy_alpha[art]
	canopy_alpha.clear()
func setup_stage() -> void:
	restore_canopies()
	for tree in get_tree().get_nodes_in_group("journey_trees"):
		if world.map.is_ancestor_of(tree) and tree.global_position.distance_to(world.player.global_position)<800:
			var art:Sprite2D=tree.get_node("Sprite2D");canopy_alpha[art]=art.self_modulate.a
	stage=Node2D.new();stage.name="AmbushStage";stage.y_sort_enabled=true
	world.add_child(stage)
	hero=actor(world.player.sprite.texture,world.player.position,64)
	hero.flip_h=world.player.sprite.flip_h
	world.player.hide()
	var camera:Camera2D=world.player.get_node("Camera2D")
	original_zoom=camera.zoom
	saved_camera_limits=Rect2(camera.limit_left,camera.limit_top,camera.limit_right-camera.limit_left,camera.limit_bottom-camera.limit_top)
	camera_was_top_level=camera.is_set_as_top_level()
	camera.zoom=Vector2.ONE*.9
	camera.set_as_top_level(true)
	camera.global_position=world.player.position+Vector2(0,75)
func actor(texture: Texture2D, point: Vector2, size: float=64) -> Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.texture=texture;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*size/maxf(texture.get_width(),texture.get_height())
	sprite.position=point
	stage.add_child(sprite)
	return sprite
func cat(point:Vector2,coat:Color) -> Sprite2D:
	var sprite:=CatActor.new();sprite.position=point;sprite.modulate=coat;sprite.ordinal=actor_count;actor_count+=1
	stage.add_child(sprite);sprite.nav=navigation
	return sprite
func walk_cat(sprite:Sprite2D,point:Vector2,pace:=120.0,obstacles:Array[Vector2]=[]) -> void:
	var route:PackedVector2Array=navigation.path(sprite.position,point,obstacles)
	if route.is_empty():
		push_error("Ambush route unavailable for "+str(sprite.name));return
	sprite.walk(route,pace)
	while is_instance_valid(sprite) and sprite.walking:await get_tree().physics_frame
func clear_points(except:Sprite2D=null) -> Array[Vector2]:
	var points:Array[Vector2]=[]
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy!=except and enemy.visible:points.append(enemy.position)
	return points
func grounded_target(wanted:Vector2,occupied:Array[Vector2]=[]) -> Vector2:
	var best:Vector2=navigation.nearest(wanted)
	if not navigation.path(hero.position,best,occupied).is_empty():return best
	for radius in [40,80,120,160,200]:
		for i in 16:
			var p:Vector2=navigation.nearest(wanted+Vector2.from_angle(i*TAU/16)*radius)
			if not navigation.path(hero.position,p,occupied).is_empty():return p
	return hero.position
func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func move(node: Node2D, point: Vector2, duration: float) -> Tween:
	var tween=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node,"position",point,duration)
	return tween
func say(speaker: String, text: String) -> void:
	spoken.append(text)
	world.dialogue.start_lines([{"speaker":speaker,"text":text}])
	await world.dialogue.finished
func _input(event: InputEvent) -> void:
	# Shared dialogue already handles Z/Enter and rejects keyboard echo.
	# A mouse press is a single deliberate advance, never a held-button poll.
	if Session.story_sequence_active and is_instance_valid(world) and world.dialogue.active and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		world.dialogue.advance()
		get_viewport().set_input_as_handled()
func start(scene: Node) -> void:
	world=scene
	lock()
	phase="coin"
	await say("", "Something seems off about this coin...")
	setup_stage()
	Music.play_theme("")
	music=AudioStreamPlayer.new();music.stream=load(SONG).duplicate();music.stream.loop=true;music.bus="Music";music.volume_db=-6
	add_child(music);music.play()
	phase="surround"
	origin=world.player.global_position
	var center:=origin
	navigation=Navigator.new();navigation.setup(world,center)
	formation=navigation.ring(center)
	if formation.size()!=8:
		finish();return
	var camera:Camera2D=world.player.get_node("Camera2D")
	move(camera,center+Vector2(0,115),.8)
	var coats:Array[Color]=[Color("#e7c9a2"),Color("#f5a66d"),Color("#bccbd5"),Color("#edddc0"),Color("#c4a7dc"),Color("#e8ba7e"),Color("#9fc2c0"),Color("#c6c6cd")]
	for i in 8:
		var target:Vector2=formation[i]
		var radial:Vector2=(target-center).normalized()
		var start:Vector2=navigation.nearest(target+radial*290+radial.orthogonal()*(35 if i%2 else -35))
		var obstacles:Array[Vector2]=formation.duplicate();obstacles.remove_at(i);obstacles.append(center)
		var route:PackedVector2Array=navigation.path(start,target,obstacles)
		if route.is_empty():
			start=navigation.nearest(target+radial*110);route=navigation.path(start,target,obstacles)
		var enemy:=cat(start,coats[i]);enemy.name=Catalog.NAMES[i];enemies.append(enemy)
		enemy.heading=(center-start).angle();enemy.walk(route,112+i%3*12,i*.23)
	for enemy in enemies:enemy.peers=enemies
	while true:
		var moving:=false
		for enemy in enemies:
			if enemy.walking:moving=true
			else:enemy.face(center)
		if not moving:break
		await get_tree().physics_frame
	await pause(.45)
	phase="taunt"
	await say("TopCat", "Look what we have here...")
	await say("", "They all laugh at you, menacingly.")
	await say("FireKitten", "There's nowhere for you to run now!")
	phase="rescue"
	var smoki_target:=grounded_target(center+Vector2(-64,8),clear_points())
	var rescue_obstacles:=clear_points();rescue_obstacles.append(center)
	var start:Vector2=navigation.nearest(center+Vector2(-420,360))
	# The reserved gap between the SW and W cats gives Smoki a clear entrance.
	if navigation.path(start,smoki_target,rescue_obstacles).is_empty():start=navigation.nearest(center+Vector2(0,400))
	smoki=cat(start,Color("#8b8298"));smoki.name="Smoki";smoki.peers=enemies
	await walk_cat(smoki,smoki_target,155,rescue_obstacles)
	smoki.face(center)
	await pause(.3)
	await say("Smoki", "Psst! Come with me!")
	var gate_point:=grounded_target(center+Vector2(90,-110),clear_points())
	var gate=portal(gate_point)
	await pause(.55)
	await walk_cat(smoki,gate.position,145,rescue_obstacles)
	smoki.hide()
	var hero_route:PackedVector2Array=navigation.path(hero.position,gate.position,clear_points())
	for i in range(1,hero_route.size()):
		await move(hero,hero_route[i],hero.position.distance_to(hero_route[i])/155).finished
	hero.hide()
	phase="charge"
	for enemy in enemies:
		var target:Vector2=navigation.nearest(gate.position+(enemy.position-gate.position).normalized()*110)
		var route:PackedVector2Array=navigation.path(enemy.position,target)
		enemy.walk(route,190)
	await pause(.75)
	for enemy in enemies:enemy.walking=false
	await pause(.32) # Deliberate held anticipation, before anyone reaches the gate.
	phase="explosion"
	sound(preload("res://assets/weather_human/wood_creak.ogg"),.65,-18)
	var blast=create_tween();blast.tween_property(gate,"burst",1.0,.75)
	for i in enemies.size():
		var scatter: Array[Vector2]=[Vector2(-245,240),Vector2(-130,270),Vector2(-20,230),Vector2(-290,330),Vector2(-180,355),Vector2(-65,335),Vector2(40,300),Vector2(-110,430)]
		launch(enemies[i],navigation.nearest(origin+scatter[i]),i)
	await pause(1.65)
	gate.queue_free()
	phase="forest_landed"
	await pause(.5)
	var fade=create_tween();fade.tween_property(music,"volume_db",-60.0,.65)
	await fade.finished
	music.stop()
	Session.area_id="wonderland_forest";Session.entry_marker="FromFlooded";Session.restore_position=false
	Session.busy=false
	if not await Session.transition_to("res://scenes/world/overworld.tscn",false,true):
		Session.area_id="flooded_forest"
		finish()
		return
	world=get_tree().current_scene
	lock()
	await arrival(true)
func portal(point: Vector2, size: float=1.0) -> Node2D:
	sound(preload("res://assets/ambience_human/drippingwater_drip_a.ogg"),1.2,-24)
	var gate=preload("res://scripts/story/ambush_portal.gd").new()
	gate.position=point;gate.scale=Vector2(.01,.01);stage.add_child(gate)
	var grow=create_tween();grow.tween_property(gate,"scale",Vector2(1,1.3)*size,.35).set_trans(Tween.TRANS_BACK)
	return gate
func launch(enemy: Sprite2D, target: Vector2, index: int) -> void:
	if enemy.get_script()==CatActor:enemy.walking=false;enemy.set_physics_process(false);enemy.get_node("GroundContact").hide()
	var origin:=enemy.position
	var tween=create_tween()
	tween.tween_method(func(t:float):
		enemy.position=origin.lerp(target,t)+Vector2(0,-sin(t*PI)*(220+index%3*35))
		enemy.rotation=t*(TAU*(2+index%3)*(1 if index%2==0 else -1)+PI*(index%2)),0.0,1.0,1.15+index*.045)
	tween.tween_callback(func():
		landed+=1
		if enemy.get_script()==CatActor:enemy.get_node("GroundContact").show())
	var scale_before:=enemy.scale
	tween.tween_property(enemy,"scale",scale_before*Vector2(1.25,.65),.08)
	tween.tween_property(enemy,"scale",scale_before,.17).set_trans(Tween.TRANS_BACK)
func arrival(tumble: bool) -> void:
	phase="arrival"
	if tumble:world.player.position+=Vector2(160,-192)
	setup_stage()
	var point:Vector2=world.player.position
	world.player.get_node("Camera2D").global_position=point+Vector2(0,-40)
	navigation=Navigator.new();navigation.setup(world,point)
	smoki=cat(point+Vector2(-85,0),Color("#8b8298"));smoki.name="Smoki"
	if tumble:
		var gate=portal(point+Vector2(-40,-115))
		hero.position=gate.position;smoki.position=gate.position
		await pause(.4)
		launch(hero,point,0);launch(smoki,point+Vector2(-85,0),1)
		await pause(1.65)
		var close=create_tween();close.tween_property(gate,"scale",Vector2.ZERO,.35)
		await close.finished;gate.queue_free()
	hero.rotation=0;smoki.rotation=0;smoki.set_physics_process(true);smoki.face(point)
	Session.story_flags["wonderland_arrived"]=true
	Session.story_flags["wonderland_fast_travel_unlocked"]=Session.story_flags.get("wonderland_fast_travel_unlocked",false)
	Session.forest_encounters.activate_checkpoint(Session.area_id,point)
	Session.persist_progress() # Arrival is real; interrupted introductions resume here.
	await pause(.65)
	phase="introduction"
	for line in INTRO:await say("Smoki",line)
	phase="departure"
	smoki.flip_h=true
	var exit_gate=portal(smoki.position+Vector2(-90,0),.65)
	await pause(.4)
	await walk_cat(smoki,exit_gate.position,130)
	smoki.hide()
	var close=create_tween();close.tween_property(exit_gate,"scale",Vector2.ZERO,.4)
	await close.finished
	Session.story_flags["wonderland_intro_completed"]=true
	Session.persist_progress()
	finish()
func finish() -> void:
	phase="complete"
	if is_instance_valid(world):
		world.player.show()
		world.player.sprite.rotation=0
		var camera:Camera2D=world.player.get_node("Camera2D")
		camera.set_as_top_level(camera_was_top_level);camera.position=Vector2.ZERO;camera.zoom=original_zoom
		camera.limit_left=int(saved_camera_limits.position.x);camera.limit_top=int(saved_camera_limits.position.y)
		camera.limit_right=int(saved_camera_limits.end.x);camera.limit_bottom=int(saved_camera_limits.end.y)
		camera.followed=world.player.global_position;camera.lead=Vector2.ZERO;camera.reset_smoothing()
		world.player.movement_locked=false
	if is_instance_valid(stage):stage.queue_free()
	Session.story_sequence_active=false;Session.busy=false
	Music.sync_scene()
	queue_free()

func sound(stream: AudioStream, pitch: float, volume: float) -> void:
	var audio:=AudioStreamPlayer.new()
	audio.stream=stream;audio.pitch_scale=pitch;audio.volume_db=volume;audio.bus="SFX"
	add_child(audio);audio.finished.connect(audio.queue_free);audio.play()

func _process(delta: float) -> void:
	# Fade only the canopy covering a cinematic actor; trunks and collisions stay intact.
	var actors:Array=[]
	for subject in enemies:
		if is_instance_valid(subject):actors.append(subject)
	if is_instance_valid(smoki):actors.append(smoki)
	if is_instance_valid(hero):actors.append(hero)
	for art in canopy_alpha:
		if not is_instance_valid(art):continue
		var blocked:=false
		for subject in actors:
			if not is_instance_valid(subject) or not subject.visible:continue
			if art.get_parent().global_position.y>subject.global_position.y and art.get_rect().has_point(art.to_local(subject.global_position-Vector2(0,28))):blocked=true;break
		art.self_modulate.a=move_toward(art.self_modulate.a,.32 if blocked else float(canopy_alpha[art]),delta*3.5)
	if is_instance_valid(world) and world.dialogue.active:
		world.dialogue.prompt_label.text="Click / "+world.dialogue.prompt_label.text

func _exit_tree() -> void:
	restore_canopies()
	enemies.clear();formation.clear();navigation=null
