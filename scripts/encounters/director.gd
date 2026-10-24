extends Node
const Catalog=preload("res://scripts/encounters/catalog.gd")
var world: Node
var service: Node
var navigation =preload("res://scripts/encounters/navigation.gd").new()
var rng =RandomNumberGenerator.new()
var actors: Array[Node]=[]
var safe_zones: Array[Vector2]=[]
var tick =0.0
var loaded =false
func _ready() -> void:
	world=get_parent();service=Session.forest_encounters
	rng.randomize();service.visit(Session.area_id)
	for actor in get_tree().get_nodes_in_group("interactables"):
		if world.map.is_ancestor_of(actor):safe_zones.append(actor.position)
	safe_zones.append(world.map.get_node("Entries/Start").position)
	for portal in world.map.get_node("Portals").get_children():safe_zones.append(portal.position)
	initialize.call_deferred()
func initialize() -> void:
	await get_tree().physics_frame;await get_tree().physics_frame
	var cache_key=Session.area_id+str(Session.story_flags.get("blankkitten_defeated",false))
	if service.navigation_cache.has(cache_key):navigation=service.navigation_cache[cache_key]
	else:
		await navigation.build(world.map)
		if navigation.ready:service.navigation_cache[cache_key]=navigation
	if not is_inside_tree() or not navigation.ready:return
	for id in service.population:
		var data:Dictionary=service.population[id]
		if data.alive and data.position.distance_to(world.player.position)<1300 and actors.size()<Catalog.MAX_POPULATION:spawn_actor(id,data)
	loaded=true
func enabled() -> bool:
	return loaded and not Session.busy and not world.dialogue.active and not world.checking_spawn and not world.automatic_encounter_pending and not Session.world_menu_open() and not get_tree().paused
func safe(point: Vector2) -> bool:
	for zone in safe_zones:
		if zone.distance_squared_to(point)<Catalog.SAFE_RADIUS*Catalog.SAFE_RADIUS:return true
	return false
func visible_world() -> Rect2:
	var camera:Camera2D=world.player.get_node("Camera2D")
	var extent:Vector2=world.get_viewport_rect().size/camera.zoom
	return Rect2(camera.get_screen_center_position()-extent*.5,extent)
func _process(delta: float) -> void:
	if not enabled():return
	tick-=delta
	if tick>0:return
	tick=.8
	# Each explored 1024px pocket owns up to four unique visit IDs. Defeated
	# IDs stay dead. Living actors leaving the active range are suspended at
	# their actual position, rather than teleported to follow the player.
	store_positions()
	var view = visible_world().grow(72)
	for actor in actors.duplicate():
		if not is_instance_valid(actor):actors.erase(actor);continue
		var slot:Dictionary=service.population.get(actor.encounter_id,{})
		if not slot.get("alive",false) or (actor.position.distance_to(world.player.position)>1300 and not view.has_point(actor.position)):
			actors.erase(actor);actor.queue_free()
	if actors.size()>=Catalog.MAX_POPULATION:return
	var pocket=Vector2i((world.player.position/1024.0).floor())
	var members=0
	for id in service.population:
		var data:Dictionary=service.population[id]
		if data.get("pocket",pocket)!=pocket:continue
		members+=1
		if not data.alive or view.has_point(data.position) or data.position.distance_to(world.player.position)>1300:continue
		var present=false
		for actor in actors:
			if actor.encounter_id==id:present=true;break
		if not present:spawn_actor(id,data);return
	if members>=Catalog.MAX_POPULATION:return
	for i in 35:
		var point:Vector2=world.player.position+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))*Vector2(view.size.x*.5+320,view.size.y*.5+320)
		point=Vector2(navigation.cell(point)*32)+Vector2(16,16)
		if view.has_point(point) or safe(point) or not navigation.valid(point):continue
		if point.distance_to(world.player.position)<360:continue
		var route = navigation.path(point,world.player.position)
		if route.is_empty() or route.size()>64:continue
		var id:int=service.population.size()
		while service.population.has(id):id+=1
		var data:Dictionary={"kind":rng.randi_range(0,7),"position":point,"home":point,"alive":true,"retreat":false,"ignore_until":service.clock+1,"pocket":pocket}
		service.population[id]=data
		spawn_actor(id,data)
		break

func spawn_actor(id: int, data: Dictionary) -> Node:
	var actor=preload("res://scripts/encounters/wanderer.gd").new()
	actor.director=self;actor.encounter_id=id;actor.kind=data.kind
	actor.position=data.position;actor.home=data.home
	actor.ignore_until=data.ignore_until
	if data.retreat:actor.state=actor.State.RETREAT
	world.map.get_node("Characters").add_child(actor)
	actors.append(actor)
	return actor
func store_positions() -> void:
	for actor in actors:
		if is_instance_valid(actor):
			var data:Dictionary=service.population.get(actor.encounter_id,{})
			data.position=actor.position
			data.retreat=actor.state==actor.State.RETREAT
			data.ignore_until=actor.ignore_until
