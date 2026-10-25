extends Node
## Persistent sequence owner: the forest scene can be freed during travel.
const Plan=preload("res://scripts/wonderland/layout.gd")
const Trap=preload("res://scripts/story/ambush_trap.gd")
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
func setup_stage() -> void:
	stage=Node2D.new();stage.name="AmbushStage";stage.z_index=20
	world.add_child(stage)
	hero=actor(world.player.sprite.texture,world.player.position,64)
	hero.flip_h=world.player.sprite.flip_h
	world.player.hide()
	var camera:Camera2D=world.player.get_node("Camera2D")
	original_zoom=camera.zoom
	camera.zoom=Vector2.ONE*.9
	camera.limit_left=-100000;camera.limit_top=-100000
	camera.limit_right=100000;camera.limit_bottom=100000
	camera.set_as_top_level(true)
	camera.global_position=world.player.position+Vector2(0,75)
func actor(texture: Texture2D, point: Vector2, size: float=64) -> Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.texture=texture;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*size/maxf(texture.get_width(),texture.get_height())
	sprite.position=point
	stage.add_child(sprite)
	return sprite
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
	var center:=Trap.POINT+Vector2(0,190)
	move(world.player.get_node("Camera2D"),Trap.POINT+Vector2(0,190),.7)
	move(hero,center,.65)
	for i in 8:
		var angle:=i*TAU/8
		var target:=center+Vector2.from_angle(angle)*105
		var enemy:=actor(Catalog.texture(i),center+Vector2(-680 if i%2==0 else 680,-85+i*6),68)
		enemy.name=Catalog.NAMES[i];enemies.append(enemy)
		move(enemy,target,.85+i*.07)
	await pause(1.5)
	phase="taunt"
	await say("TopCat", "Look what we have here...")
	await say("", "They all laugh at you, menacingly.")
	await say("FireKitten", "There's nowhere for you to run now!")
	phase="rescue"
	smoki=actor(preload("res://assets/bartboss.png"),center+Vector2(-690,-35),70)
	await move(smoki,center+Vector2(-40,-25),.6).finished
	for i in enemies.size():
		var startled=create_tween()
		startled.tween_property(enemies[i],"position:y",enemies[i].position.y-18,.12)
		startled.tween_property(enemies[i],"position:y",enemies[i].position.y,.18)
	await pause(.35)
	await say("Smoki", "Psst! Come with me!")
	var gate=portal(center+Vector2(140,-115))
	await pause(.45)
	move(smoki,gate.position,.6)
	await move(hero,gate.position,.6).finished
	hero.hide();smoki.hide()
	phase="charge"
	for enemy in enemies:move(enemy,gate.position+(enemy.position-gate.position).normalized()*90,.45)
	await pause(.45)
	await pause(.32) # Deliberate held anticipation, before anyone reaches the gate.
	phase="explosion"
	sound(preload("res://assets/weather_human/wood_creak.ogg"),.65,-18)
	var blast=create_tween();blast.tween_property(gate,"burst",1.0,.75)
	for i in enemies.size():
		var scatter: Array[Vector2]=[Vector2(-245,240),Vector2(-130,270),Vector2(-20,230),Vector2(-290,330),Vector2(-180,355),Vector2(-65,335),Vector2(40,300),Vector2(-110,430)]
		launch(enemies[i],Trap.POINT+scatter[i],i)
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
	var origin:=enemy.position
	var tween=create_tween()
	tween.tween_method(func(t:float):
		enemy.position=origin.lerp(target,t)+Vector2(0,-sin(t*PI)*(220+index%3*35))
		enemy.rotation=t*(TAU*(2+index%3)*(1 if index%2==0 else -1)+PI*(index%2)),0.0,1.0,1.15+index*.045)
	tween.tween_callback(func():landed+=1)
	var scale_before:=enemy.scale
	tween.tween_property(enemy,"scale",scale_before*Vector2(1.25,.65),.08)
	tween.tween_property(enemy,"scale",scale_before,.17).set_trans(Tween.TRANS_BACK)
func arrival(tumble: bool) -> void:
	phase="arrival"
	if tumble:world.player.position+=Vector2(160,-192)
	setup_stage()
	var point:Vector2=world.player.position
	world.player.get_node("Camera2D").global_position=point+Vector2(0,-40)
	smoki=actor(preload("res://assets/bartboss.png"),point+Vector2(-85,0),70)
	if tumble:
		var gate=portal(point+Vector2(-40,-115))
		hero.position=gate.position;smoki.position=gate.position
		await pause(.4)
		launch(hero,point,0);launch(smoki,point+Vector2(-85,0),1)
		await pause(1.65)
		var close=create_tween();close.tween_property(gate,"scale",Vector2.ZERO,.35)
		await close.finished;gate.queue_free()
	hero.rotation=0;smoki.rotation=0
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
	await move(smoki,exit_gate.position,.6).finished
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
		camera.set_as_top_level(false);camera.position=Vector2.ZERO;camera.zoom=original_zoom
		camera.limit_left=0;camera.limit_top=0
		camera.limit_right=int(world.map.map_size.x);camera.limit_bottom=int(world.map.map_size.y)
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

func _process(_delta: float) -> void:
	if is_instance_valid(world) and world.dialogue.active:
		world.dialogue.prompt_label.text="Click / "+world.dialogue.prompt_label.text
