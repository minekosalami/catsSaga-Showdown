extends Node2D

const Energy = preload("res://scripts/ui/energy_laser_style.gd")
const RED := Color("#FF2347")
# Defaults sequence full existing blue convergence first, then the red formation.
@export var start_time := 70.40
@export var end_time := 89.60
@export var warning_start := 79.20
@export var warning_duration := 0.80
@export var charging_duration := 1.60
@export var activation_duration := 7.60
@export var initial_rotation_speed := 0.32 # radians/second, clockwise in canvas coordinates
@export var maximum_rotation_speed := 1.10
@export_range(0.5,4.0,0.1) var acceleration_curve := 1.4
@export var reversal_interval := 1.60 # one measure at 150 BPM
@export var reversal_easing := 0.28
@export var pivot_center := Vector2(270,400)
@export var pivot_amplitude := Vector2(72,55)
@export var pivot_cycle := 6.40
@export var pivot_bounds := Rect2(150,310,240,190)
@export var beam_width := 24.0
@export var beam_length := 1600.0
@export_range(0.0,1.0,0.05) var glow_intensity := 0.65
@export var shatter_time := 89.20
@export_range(8,96,1) var fragment_count := 64
@export var fragment_velocity := 280.0
@export var fragment_lifetime := 0.38
var clock := 0.0
var active := false
var warning := false
var charging := false
var shattering := false
var angular_speed := 0.0
var energy := 0.0
var beams: Array[Area2D] = []
var shapes: Array[CollisionShape2D] = []
var fragments: Array[Dictionary] = []
var shatter_count := 0
var cancelled := false
var last_clock := -1.0
var integral := PackedFloat64Array([0.0])
var integral_key := ""

func activation_time() -> float:
	return maxf(start_time,warning_start)+warning_duration+charging_duration

func break_time() -> float:
	return maxf(activation_time(),minf(end_time,minf(shatter_time,activation_time()+activation_duration)))

func _ready() -> void:
	z_index = -1
	for i in range(2):
		var beam := Area2D.new()
		beam.name = "Horizontal" if i == 0 else "Vertical"
		beam.rotation = i*PI/2
		beam.collision_layer = 4
		beam.collision_mask = 2
		beam.add_to_group("boss2_lasers")
		add_child(beam)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.disabled = true
		beam.add_child(shape)
		beams.append(beam)
		shapes.append(shape)
	_set_shapes(false)
	hide()

func _set_shapes(enabled: bool) -> void:
	for shape in shapes:
		(shape.shape as RectangleShape2D).size = Vector2(beam_length,beam_width)
		shape.set_deferred("disabled",not enabled)

func cancel() -> void:
	cancelled = true
	active = false
	warning = false
	charging = false
	shattering = false
	fragments.clear()
	_set_shapes(false)
	hide()

func sample(playback: float) -> void:
	clock = playback
	if cancelled:
		return
	# Deterministic seeking and retry; no frame/delta accumulation for pose or shards.
	if playback < last_clock:
		fragments.clear()
		shatter_count = 0
	last_clock = playback
	var warning_begin := maxf(start_time,warning_start)
	var begins := activation_time()
	var breaks := break_time()
	warning = clock >= warning_begin and clock < warning_begin+warning_duration
	charging = clock >= warning_begin+warning_duration and clock < begins
	active = clock >= begins and clock < breaks and clock < end_time
	shattering = clock >= breaks and clock < end_time
	visible = clock >= warning_begin and clock < end_time
	_set_shapes(active)
	energy = pow(clampf((clock-begins)/maxf(0.001,breaks-begins),0,1),acceleration_curve)
	var motion_time := clampf(clock,begins,breaks)-begins
	position = pivot_at(maxf(0,motion_time))
	rotation = angle_at(maxf(0,motion_time))
	angular_speed = velocity_at(maxf(0,motion_time)) if active else 0
	if shattering and fragments.is_empty():
		_build_fragments()
	if clock >= end_time or clock < begins:
		fragments.clear()
	queue_redraw()

func pivot_at(t: float) -> Vector2:
	# Starts at rest; intentional bounded ellipse with no player tracking.
	var p := t*TAU/maxf(0.1,pivot_cycle)
	var envelope := smoothstep(0,0.8,t)
	var point := pivot_center+Vector2(sin(p),sin(p*0.5))*pivot_amplitude*envelope
	return Vector2(clampf(point.x,pivot_bounds.position.x,pivot_bounds.end.x),clampf(point.y,pivot_bounds.position.y,pivot_bounds.end.y))

func velocity_at(t: float) -> float:
	var span := maxf(0.001,break_time()-activation_time())
	var speed := lerpf(initial_rotation_speed,maximum_rotation_speed,pow(clampf(t/span,0,1),acceleration_curve))
	var interval := maxf(0.2,reversal_interval)
	var cycle := int(t/interval)
	var sign_now := 1.0 if cycle%2 == 0 else -1.0
	var local := fmod(t,interval)
	var reverse := minf(reversal_easing,interval*0.45)
	if cycle > 0 and local < reverse:
		sign_now *= lerpf(-1,1,smoothstep(0,reverse,local))
	# Slow first launch; reversals smoothly pass through zero angular velocity.
	return speed*sign_now*smoothstep(0,0.35,t)

func angle_at(t: float) -> float:
	# Cache a fixed-grid integral of the analytical velocity. Frames only sample
	# this curve; seeking or frame rate cannot alter the resulting pose.
	const STEP := 1.0/120.0
	var key := str([initial_rotation_speed,maximum_rotation_speed,acceleration_curve,reversal_interval,reversal_easing,break_time(),activation_time()])
	if key != integral_key:
		integral_key = key
		integral = PackedFloat64Array([0.0])
	var count := int(t/STEP)
	while integral.size() <= count:
		var i := integral.size()-1
		integral.append(integral[i]+(velocity_at(i*STEP)+velocity_at((i+1)*STEP))*STEP*0.5)
	var remainder := t-count*STEP
	return integral[count]+(velocity_at(count*STEP)+velocity_at(t))*remainder*0.5

func _physics_process(_delta: float) -> void:
	if not active:
		return
	for shape in shapes:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for hit in get_world_2d().direct_space_state.intersect_shape(query,4):
			if hit.collider.is_in_group("player"):
				hit.collider.take_damage(1)

func _draw() -> void:
	if shattering:
		_draw_fragments()
		return
	for i in range(2):
		draw_set_transform(Vector2.ZERO,i*PI/2)
		if warning or charging:
			_draw_warning()
		if active:
			Energy.draw_beam(self,beam_length,beam_width,RED,clock,energy,glow_intensity)
			var crack := smoothstep(break_time()-0.12,break_time(),clock)
			if crack > 0:
				draw_rect(Rect2(-beam_length/2,-beam_width/2,beam_length,beam_width),Color(1,1,1,crack*0.25))
				for j in range(12):
					var x := -500+j*90
					draw_polyline(PackedVector2Array([Vector2(x,-beam_width/2),Vector2(x+6,0),Vector2(x-3,beam_width/2)]),Color(1,1,1,crack),1,true)
	draw_set_transform(Vector2.ZERO)

func _draw_warning() -> void:
	var pulse := 0.12+0.05*sin(clock*TAU/0.8)
	draw_rect(Rect2(-beam_length/2,-beam_width/2,beam_length,beam_width),Color(RED,pulse))
	for side in [-1,1]:
		draw_line(Vector2(-beam_length/2,side*beam_width/2),Vector2(beam_length/2,side*beam_width/2),Color(RED,0.8),1,true)
	draw_line(Vector2(-beam_length/2,0),Vector2(beam_length/2,0),Color(1,0.5,0.5,0.9),1,true)
	for x in [-210,210]:
		var triangle := PackedVector2Array([Vector2(x,-18),Vector2(x-7,-31),Vector2(x+7,-31)])
		draw_colored_polygon(triangle,RED)
		draw_line(Vector2(x,-28),Vector2(x,-23),Color.WHITE,1)
	if charging:
		var build := smoothstep(0,charging_duration,clock-maxf(start_time,warning_start)-warning_duration)
		draw_rect(Rect2(-beam_length/2,-2,beam_length,4),Color(1,0.65,0.65,build*0.65))
		draw_circle(Vector2.ZERO,12+5*build,Color(RED,0.15))

func _build_fragments() -> void:
	shatter_count += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1940892
	for i in range(fragment_count):
		var axis := i%2
		var along := rng.randf_range(-540,540)
		var source := Vector2(along,rng.randf_range(-beam_width/2,beam_width/2)).rotated(axis*PI/2)
		var side := -1 if i%4 < 2 else 1
		var velocity := Vector2(rng.randf_range(-0.3,0.3),side*rng.randf_range(0.6,1.4)).rotated(axis*PI/2)*fragment_velocity
		var size := rng.randf_range(4,13)
		var polygon := PackedVector2Array()
		var vertices := 3+i%3
		for j in range(vertices):
			polygon.append(Vector2.RIGHT.rotated(j*TAU/vertices+rng.randf_range(-0.12,0.12))*size*rng.randf_range(0.55,1.15))
		fragments.append({"origin":source,"velocity":velocity,"spin":rng.randf_range(-9,9),"angle":rng.randf_range(0,TAU),"polygon":polygon})


func _draw_fragments() -> void:
	var age := maxf(0,clock-break_time())
	var fade := 1-smoothstep(0,minf(fragment_lifetime,end_time-break_time()),age)
	var travel := (1-exp(-age*5))/5
	for piece in fragments:
		var point: Vector2 = piece.origin+piece.velocity*travel
		draw_set_transform(point,piece.angle+piece.spin*age)
		draw_set_transform(point,piece.angle+piece.spin*age,Vector2.ONE*1.25)
		draw_colored_polygon(piece.polygon,Color(RED,fade*0.07*glow_intensity))
		draw_set_transform(point,piece.angle+piece.spin*age)
		draw_colored_polygon(piece.polygon,Color(RED.lightened(0.25),fade*0.8))
		draw_polyline(piece.polygon,Color(1,0.95,0.95,fade),1,true)
		draw_line(Vector2.ZERO,-piece.velocity.rotated(-piece.angle-piece.spin*age)*0.025,Color(RED,fade*0.35),1,true)
	draw_set_transform(Vector2.ZERO)
