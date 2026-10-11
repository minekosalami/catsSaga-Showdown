extends Node2D
func _draw() -> void:
	var battle := get_parent()
	if battle.timeline == null:
		return
	var boss: Sprite2D = battle.timeline.boss
	var point: Vector2 = boss.position
	draw_set_transform(point+Vector2(0,78),0,Vector2(1,0.23))
	for i in range(6,0,-1):
		draw_circle(Vector2.ZERO,48+i*5,Color(0.01,0.03,0.06,0.035))
	draw_set_transform(point,0,Vector2(1,0.8))
	draw_texture_rect_region(preload("res://scripts/ui/projectile_energy.gd").shared_atlas(),Rect2(-110,-110,220,220),Rect2(0,128,64,64),Color("#60D8FF"))
	draw_set_transform(Vector2.ZERO)
