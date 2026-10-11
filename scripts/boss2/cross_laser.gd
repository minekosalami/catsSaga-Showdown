extends Node2D
const Energy = preload("res://scripts/ui/energy_laser_style.gd")
const RED := Color("#FF2347")
@export var start_time := 70.40
@export var end_time := 89.60
@export var warning_duration := 0.80
@export var charging_duration := 0.80
@export var maximum_rpm := 50.0
@export var acceleration_seconds := 3.2
@export var deceleration_seconds := 3.2
@export var pivot_center := Vector2(270,410)
@export var beam_width := 24.0 # visual energy only
@export var core_width := 3.0 # the sole damaging width, drawn explicitly white
@export var beam_length := 1600.0
@export_range(0.0,1.0,0.05) var glow_intensity := 0.65
@export_range(8,96,1) var fragment_count := 64
@export var fragment_velocity := 280.0
@export var fragment_lifetime := 0.5
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
var last_damage_clock := -1.0

func activation_time() -> float:
	return snappedf(start_time+warning_duration+charging_duration,0.000001)

func break_time() -> float:
	return end_time

func _ready() -> void:
	z_index = -1
	position = pivot_center
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
		(shape.shape as RectangleShape2D).size = Vector2(beam_length,core_width)
		shape.set_deferred("disabled",not enabled)
	# Layer changes are immediate; deferred shape updates cannot leave a live hit.
	for beam in beams:
		beam.collision_layer = 4 if enabled else 0
		beam.collision_mask = 2 if enabled else 0

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
	if playback < last_clock:
		fragments.clear()
		shatter_count = 0
		last_damage_clock = -1
	last_clock = playback
	var begins := activation_time()
	var warning_end := snappedf(start_time+warning_duration,0.000001)
	warning = clock >= start_time and clock < warning_end-0.000000001
	charging = clock >= warning_end-0.000000001 and clock < begins
	active = clock >= begins and clock < end_time
	shattering = clock >= end_time and clock < end_time+fragment_lifetime
	visible = warning or charging or active or shattering
	_set_shapes(active)
	position = pivot_center
	rotation = angle_at(clampf(clock-begins,0,end_time-begins))
	angular_speed = velocity_at(clock-begins) if active else 0
	energy = angular_speed/maxf(0.001,maximum_rpm*TAU/60)
	if shattering and fragments.is_empty():
		_build_fragments()
	if clock >= end_time+fragment_lifetime or clock < begins:
		fragments.clear()
	if not active:
		last_damage_clock = -1
	queue_redraw()

func pivot_at(_t: float) -> Vector2:
	return pivot_center

func velocity_at(t: float) -> float:
	var span := end_time-activation_time()
	var maximum := maximum_rpm*TAU/60
	if t <= 0 or t >= span:
		return 0
	if t < acceleration_seconds:
		return maximum*(1-cos(PI*t/acceleration_seconds))*0.5
	if t > span-deceleration_seconds:
		return maximum*(1+cos(PI*(t-(span-deceleration_seconds))/deceleration_seconds))*0.5
	return maximum

func angle_at(t: float) -> float:
	# Closed-form integral of the sine-eased speed, sampled from music time.
	var maximum := maximum_rpm*TAU/60
	var span := end_time-activation_time()
	var time := clampf(t,0,span)
	var a := minf(time,acceleration_seconds)
	var angle := maximum*0.5*(a-acceleration_seconds/PI*sin(PI*a/acceleration_seconds))
	angle += maximum*clampf(time-acceleration_seconds,0,span-acceleration_seconds-deceleration_seconds)
	var d := clampf(time-(span-deceleration_seconds),0,deceleration_seconds)
	angle += maximum*0.5*(d+deceleration_seconds/PI*sin(PI*d/deceleration_seconds))
	return angle

func swept_contact(before: Vector2, after: Vector2, from_clock: float, to_clock: float, radius: float) -> bool:
	# Relative polar motion against four arms. Small substeps bound curvature of
	# the player's straight physics segment; crossing a quadrant detects an arm
	# even when the fast beam has passed entirely between two rendered poses.
	var steps := maxi(1,ceili(maxf(0,to_clock-from_clock)*240))
	for i in range(steps):
		var a := before.lerp(after,i/float(steps))-pivot_center
		var b := before.lerp(after,(i+1)/float(steps))-pivot_center
		var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b).length()
		if closest <= radius+core_width/2:
			return true
		var ta := lerpf(from_clock,to_clock,i/float(steps))-activation_time()
		var tb := lerpf(from_clock,to_clock,(i+1)/float(steps))-activation_time()
		var relative_a := a.angle()-angle_at(ta)
		var relative_b := a.angle()+wrapf(b.angle()-a.angle(),-PI,PI)-angle_at(tb)
		var tolerance := asin(clampf((radius+core_width/2)/closest,0,1))
		var low := minf(relative_a,relative_b)-tolerance
		var high := maxf(relative_a,relative_b)+tolerance
		if ceil(low/(PI/2)) <= floor(high/(PI/2)):
			return true
	return false

func _physics_process(delta: float) -> void:
	if not active:
		return
	var player: Node = get_parent().battle.player
	var from_clock := maxf(activation_time(),clock-delta) if last_damage_clock < 0 else last_damage_clock
	last_damage_clock = clock
	if swept_contact(player.previous_hit_center,player.hit_center(),from_clock,clock,player.damage_hitbox_radius):
		player.notify_laser_contact(player.hit_center())
		player.take_damage(1)

func _draw() -> void:
	if shattering:
		_draw_fragments()
		return
	for i in range(2):
		draw_set_transform(Vector2.ZERO,i*PI/2)
		if warning or charging:
			var alpha := 0.4 if charging else 0.22
			draw_rect(Rect2(-beam_length/2,-core_width/2,beam_length,core_width),Color(RED,alpha))
			draw_line(Vector2(-beam_length/2,-beam_width/2),Vector2(beam_length/2,-beam_width/2),Color(RED,0.35),1,true)
			draw_line(Vector2(-beam_length/2,beam_width/2),Vector2(beam_length/2,beam_width/2),Color(RED,0.35),1,true)
		if active:
			Energy.draw_beam(self,beam_length,beam_width,RED,clock,energy,glow_intensity)
			draw_rect(Rect2(-beam_length/2,-core_width/2,beam_length,core_width),Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO,12,Color(RED,0.5))
	draw_arc(Vector2.ZERO,13,0,TAU,32,Color.WHITE,1.5,true)
	draw_circle(Vector2.ZERO,3,Color.WHITE)

func _build_fragments() -> void:
	shatter_count += 1
	get_parent().battle.effects.burst(position,RED,12,240,0.35)
	get_parent().battle.effects.burst(position,Color.WHITE,8,170,0.28)
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
	var fade := 1-smoothstep(0,fragment_lifetime,age)
	var travel := (1-exp(-age*5))/5
	for piece in fragments:
		var point: Vector2 = piece.origin+piece.velocity*travel
		draw_set_transform(point,piece.angle+piece.spin*age,Vector2.ONE*1.25)
		draw_colored_polygon(piece.polygon,Color(RED,fade*0.07*glow_intensity))
		draw_set_transform(point,piece.angle+piece.spin*age)
		draw_colored_polygon(piece.polygon,Color(RED.lightened(0.25),fade*0.8))
		draw_polyline(piece.polygon,Color(1,0.95,0.95,fade),1,true)
		draw_line(Vector2.ZERO,-piece.velocity.rotated(-piece.angle-piece.spin*age)*0.025,Color(RED,fade*0.35),1,true)
	draw_set_transform(Vector2.ZERO)
