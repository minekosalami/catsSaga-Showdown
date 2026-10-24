extends Area2D
signal health_changed(value: int)
const Catalog=preload("res://scripts/encounters/catalog.gd")
var health =Catalog.ENEMY_HP
var max_health =Catalog.ENEMY_HP
var kind =0
var battle: Node
var age =0.0
var firing_timer =1.2
var volley =0
var rng =RandomNumberGenerator.new()
var sprite: Sprite2D
func _ready() -> void:
	add_to_group("enemies")
	collision_layer=4;collision_mask=0
	monitoring=false
	var hit =CollisionShape2D.new()
	var shape =RectangleShape2D.new()
	shape.size=Vector2(104,76)
	hit.shape=shape
	add_child(hit)
	sprite=Sprite2D.new()
	sprite.texture=Catalog.texture(kind)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*112.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
	add_child(sprite)
	# BiNarty's original very dark lines are retained, with a contrasting backing.
	if kind==4:queue_redraw()
	rng.randomize()
func _draw() -> void:
	if kind==4:draw_circle(Vector2.ZERO,62,Color("#515566"))
func _physics_process(delta: float) -> void:
	if battle.game_over or battle.victory_started:return
	age+=delta
	position=Vector2(270+sin(age*.9)*160,200)
	firing_timer-=delta
	if firing_timer<=0:
		fire_pattern()
		firing_timer=rng.randf_range(.9,1.3)
func fire_pattern() -> void:
	volley+=1
	var aimed:float=(battle.player.position-position).angle()
	var offset =rng.randf_range(-.12,.12)
	# Eight families, 10–13 shots per volley, same bounded speed and interval
	# distribution throughout the song. A moving corridor always remains.
	match kind:
		0:
			for i in range(11):shot(PI*.5+(i-5)*.14+offset,165)
		1:
			for i in range(12):shot(aimed+(i%4-1.5)*.18+offset,155+(i/4)*15)
		2:
			for i in range(11):shot(PI*.5+(i-5)*.22+offset,175)
		3:
			for i in range(10):shot(aimed+(i-4.5)*.095+offset,195 if i%2 else 170)
		4:
			for i in range(12):shot(PI*.5+(i-5.5)*.15+offset,175, .22 if i%2 else -.22)
		5:
			for i in range(12):shot(aimed+(i%6-2.5)*.19+offset,155+(i/6)*25)
		6:
			for i in range(10):shot(aimed+(i-4.5)*.12+offset,205)
		7:
			for i in range(12):shot(PI*.5+(i-5.5)*.17+sin(volley*.8)*.2+offset,170,.3 if volley%2 else -.3)
func shot(angle: float, velocity: float, turn:=0.0) -> void:
	if battle.projectile_count()>=Catalog.BULLET_CAP:return
	var bullet=load("res://scenes/enemybullet.tscn").instantiate()
	bullet.set_script(preload("res://scripts/encounters/projectile.gd"))
	bullet.theme=kind
	bullet.speed=velocity*rng.randf_range(.96,1.04)
	bullet.direction=Vector2.from_angle(angle)
	bullet.angular_velocity=turn
	bullet.turn_duration=.8
	bullet.bullet_color=Catalog.COLORS[kind]
	bullet.position=position+Vector2(0,44)
	battle.add_child(bullet)
func take_damage(amount: int) -> void:
	if health<=0 or battle.game_over or battle.victory_started:return
	health=maxi(0,health-amount)
	health_changed.emit(health)
	if health==0:battle.finish("victory")
