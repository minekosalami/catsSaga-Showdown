extends SceneTree
## Real physics/input and render-frame measurements, with no generated assets.
class MotionSamples extends Node:
	var actor: Node2D
	var camera: Camera2D
	var points: Array[Dictionary] = []
	func _process(delta: float) -> void:
		var screen: Vector2=get_tree().root.get_stretch_transform()*actor.sprite.get_global_transform_with_canvas().origin
		points.append({"body":actor.global_position,"visual":actor.sprite.global_position,"camera":camera.global_position,"screen":screen,"delta":delta})

var checks := 0
var failures := 0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use CATSSAGA_TEST_PROFILE=1 and an isolated XDG_DATA_HOME.")
		quit(1)
		return
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)
func run() -> void:
	Engine.max_fps=240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene=stage
	var actor: Node2D=load("res://scenes/world/player.tscn").instantiate()
	actor.position=Vector2(2000,2000)
	stage.add_child(actor)
	var camera: Camera2D=actor.get_node("Camera2D")
	var settings := root.get_node("GameSettings")
	root.get_node("Session").busy=false
	await process_frame
	# Exercise a fractional camera zoom and a non-design window aspect/scale.
	settings.values.zoom=.75
	root.size=Vector2i(1600,1000)
	Input.action_press("move_right")
	await create_timer(1.5).timeout
	var samples := MotionSamples.new()
	samples.actor=actor;samples.camera=camera;samples.process_priority=100
	stage.add_child(samples)
	await create_timer(1.2).timeout
	samples.set_process(false)
	check(samples.points.size()>100,"render sampling runs faster than the 60 Hz physics step")
	var interpolated_steps := 0
	var fractional_centers := 0
	var speeds: Array[float]=[]
	var screen_min := INF
	var screen_max := -INF
	for i in range(1,samples.points.size()):
		var now: Dictionary=samples.points[i]
		var before: Dictionary=samples.points[i-1]
		if now.body.distance_to(before.body)<.0001 and now.visual.x-before.visual.x>.02:interpolated_steps+=1
		if now.camera.distance_to((now.camera/2.0).round()*2.0)>.01:fractional_centers+=1
		speeds.append((now.camera.x-before.camera.x)/now.delta)
		screen_min=minf(screen_min,now.screen.x)
		screen_max=maxf(screen_max,now.screen.x)
	var mean := 0.0
	for speed in speeds:mean+=speed/maxi(1,speeds.size())
	var variance := 0.0
	for speed in speeds:variance+=pow(speed-mean,2)/maxi(1,speeds.size())
	print("MOTION samples=",samples.points.size()," interpolated_steps=",interpolated_steps," mean_camera_speed=",mean," relative_speed_deviation=",sqrt(variance)/maxf(1,mean)," cat_screen_travel=",screen_max-screen_min)
	check(interpolated_steps>samples.points.size()/4,"cat presentation advances smoothly between fixed physics ticks")
	check(fractional_centers>samples.points.size()*.9,"camera centers avoid world-grid snapping at fractional display scales")
	check(absf(mean-actor.speed)<3 and sqrt(variance)/maxf(1,mean)<.08,"constant walking produces stable camera speed across render frames")
	check(screen_max-screen_min<1.2,"tracked cat stays stable in the viewport during steady walking")
	check(actor.sprite.offset==actor.get_node("MovementVisual").rest_offset and absf(actor.sprite.rotation)<.001,"ordinary movement introduces no sprite bob or roll")
	Input.action_release("move_right")
	await create_timer(.35).timeout
	var facing: bool=actor.sprite.flip_h
	await create_timer(.1).timeout
	check(actor.sprite.flip_h==facing and actor.velocity.length()<.01,"stopping preserves facing and normal movement physics")
	settings.values.zoom=.8
	await process_frame
	await process_frame
	check(camera.zoom.is_equal_approx(Vector2.ONE*.8),"exploration visibility setting still controls camera zoom")
	actor.position+=Vector2(1800,600)
	await process_frame
	await process_frame
	print("TELEPORT visual_offset=",actor.sprite.position," camera_target_error=",camera.global_position.distance_to(actor.position+camera.lead)," lead=",camera.lead," actor=",actor.position," camera=",camera.global_position)
	check(actor.sprite.position.length()<.01 and camera.global_position.distance_to(actor.position+camera.lead)<.5,"teleports reset presentation history instead of sliding through the map")
	stage.queue_free()
	await process_frame
	print("CAMERA STABILITY: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
