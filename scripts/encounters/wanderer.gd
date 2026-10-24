extends CharacterBody2D
const Catalog=preload("res://scripts/encounters/catalog.gd")
enum State { WANDER, CHASE, SEARCH, RETREAT }
var state =State.WANDER
var director: Node
var encounter_id: int
var kind =0
var home =Vector2.ZERO
var ignore_until =0.0
var last_seen =Vector2.ZERO
var search_remaining =0.0
var think_timer =0.0
var path =PackedVector2Array()
var waypoint =0
var wander_wait =0.0
var sprite: Sprite2D
func _ready() -> void:
	collision_layer=4;collision_mask=1
	var collision =CollisionShape2D.new()
	collision.name="CollisionShape2D"
	var circle =CircleShape2D.new();circle.radius=12
	collision.shape=circle;add_child(collision)
	sprite=Sprite2D.new();sprite.texture=Catalog.texture(kind)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE*58.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
	sprite.position.y=-22
	add_child(sprite)
	add_to_group("ordinary_wanderers")
	queue_redraw()
func _draw() -> void:
	if kind==4:draw_circle(Vector2(0,-22),31,Color("#74807b"))
func can_see() -> bool:
	var player:Node2D=director.world.player
	if position.distance_to(player.position)>Catalog.DETECTION_RADIUS or director.safe(player.position):return false
	var ray =PhysicsRayQueryParameters2D.create(global_position,player.global_position,1,[get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func set_target(point: Vector2) -> void:
	path=director.navigation.path(position,point);waypoint=0
	if path.size()>1:waypoint=1
func _physics_process(delta: float) -> void:
	if not director.enabled():velocity=Vector2.ZERO;return
	var player:Node2D=director.world.player
	if position.distance_to(player.position)>1450:
		velocity=Vector2.ZERO;return # No offscreen pathfinding or animation work.
	think_timer-=delta
	search_remaining-=delta
	wander_wait-=delta
	if think_timer<=0:
		think_timer=.3
		var sees =ignore_until<=director.service.clock and can_see()
		if state!=State.RETREAT and sees and position.distance_to(home)<Catalog.PURSUIT_LEASH:
			state=State.CHASE;last_seen=player.position;set_target(last_seen)
		elif state==State.CHASE:
			if position.distance_to(home)>=Catalog.PURSUIT_LEASH:state=State.RETREAT;set_target(home)
			else:state=State.SEARCH;search_remaining=director.rng.randf_range(3,5);set_target(last_seen)
		elif state==State.SEARCH:
			if search_remaining<=0:state=State.RETREAT;set_target(home)
		elif state==State.RETREAT:
			if position.distance_to(home)<48:state=State.WANDER
			elif waypoint>=path.size():set_target(home)
		elif state==State.WANDER and waypoint>=path.size() and wander_wait<=0:
			set_target(home+Vector2.from_angle(director.rng.randf()*TAU)*director.rng.randf_range(48,240))
			wander_wait=director.rng.randf_range(2,4)
	if waypoint<path.size():
		if position.distance_to(path[waypoint])<7:waypoint+=1
		else:
			var target:Vector2=path[waypoint]
			if director.safe(target):path.clear();velocity=Vector2.ZERO;return
			velocity=position.direction_to(target)*(Catalog.CHASE_SPEED if state==State.CHASE else Catalog.WANDER_SPEED)
			move_and_slide()
			if absf(velocity.x)>1:sprite.flip_h=velocity.x<0
	else:velocity=Vector2.ZERO
	if state!=State.RETREAT and ignore_until<=director.service.clock and position.distance_to(player.position)<34:
		director.service.begin(director.world,self)
