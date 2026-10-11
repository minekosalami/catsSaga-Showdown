extends "res://scripts/enemybullet.gd"
var dangerous := true
var grazed := false
var bounce_flash := 0.0

func _physics_process(delta: float) -> void:
	if not dangerous:
		return
	var before := global_position
	super._physics_process(delta)
	test_segment(before,global_position)
	bounce_flash = maxf(0,bounce_flash-delta)

func test_segment(before: Vector2, after: Vector2, fraction_start: float = 0, fraction_end: float = 1) -> void:
	var player: Node = get_parent().player
	if not dangerous or player.health <= 0:
		return
	var center: Vector2 = player.hit_center()
	var previous: Vector2 = player.previous_hit_center
	var relative_start := before-previous.lerp(center,fraction_start)
	var relative_end := after-previous.lerp(center,fraction_end)
	var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,relative_start,relative_end)
	var radius: float = body_radius+player.damage_hitbox_radius
	if closest.length() <= radius:
		player.take_damage(1)
		dissolve(false)
	elif not grazed and closest.length() <= radius+8:
		grazed = true
		get_parent().effects.graze(center+closest*0.5,bullet_color)

func _on_area_entered(area: Area2D) -> void:
	if dangerous and area.is_in_group("player"):
		area.take_damage(1)
		dissolve(false)

func dissolve(shatter: bool = false) -> void:
	if not dangerous:
		return
	dangerous = false
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitoring",false)
	if not shatter:
		get_parent().effects.dissolve(global_position,bullet_color,body_radius)
	get_parent().effects.burst(global_position,bullet_color,6 if shatter else 3,130 if shatter else 35,0.35,shatter)
	queue_free()

func _draw() -> void:
	super._draw()
	if bounce_flash > 0:
		draw_circle(Vector2.ZERO,body_radius,Color(1,1,1,bounce_flash/0.12*0.65))
