extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	create_timer(70).timeout.connect(func():push_error("AI timeout");quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var s=root.get_node("Session")
	await s.new_game(2)
	var w=current_scene
	while not w.encounters.loaded:await process_frame
	var director=w.encounters
	director.set_process(false)
	s.forest_encounters.protection_until=INF
	# Find an actual connected, safe, obstacle-free straight stretch.
	var a:=Vector2.ZERO
	var b:=Vector2.ZERO
	var nav=director.navigation
	for y in range(4,nav.grid.region.size.y-4):
		if a!=Vector2.ZERO:break
		for x in range(4,nav.grid.region.size.x-10):
			var p:=Vector2(x*32+16,y*32+16)
			var target:=p+Vector2(192,0)
			if director.safe(p) or director.safe(target):continue
			var path=nav.path(p,target)
			if not nav.valid(p) or not nav.valid(target) or path.size()!=7:continue
			var ray=PhysicsRayQueryParameters2D.create(p,target,1)
			if not w.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():continue
			a=p;b=target;break
	check(a!=Vector2.ZERO,"safe connected AI test route found")
	w.player.position=b
	var data={"kind":0,"position":a,"home":a,"alive":true,"retreat":false,"ignore_until":0.0}
	s.forest_encounters.population[0]=data
	var actor=director.spawn_actor(0,data)
	await create_timer(.4).timeout
	check(actor.can_see() and actor.state==actor.State.CHASE,"line of sight initiates chase")
	var before:Vector2=actor.position
	await create_timer(.5).timeout
	check(actor.position.distance_to(b)<before.distance_to(b),"chase physically follows navigable path")
	actor.position=a;actor.velocity=Vector2.ZERO
	var wall:=StaticBody2D.new()
	wall.collision_layer=1
	var collision:=CollisionShape2D.new()
	var box:=RectangleShape2D.new();box.size=Vector2(20,140)
	collision.shape=box;wall.add_child(collision)
	wall.position=(a+b)*.5;w.add_child(wall)
	await physics_frame;await physics_frame
	check(not actor.can_see(),"obstacle blocks vision")
	actor.state=actor.State.CHASE;actor.think_timer=0
	await create_timer(.35).timeout
	check(actor.state==actor.State.SEARCH and actor.search_remaining>2.5 and actor.search_remaining<=5,"lost sight searches for 3–5 seconds")
	actor.search_remaining=.05
	await create_timer(.4).timeout
	check(actor.state==actor.State.RETREAT or actor.state==actor.State.WANDER,"search expiry returns toward home")
	wall.queue_free();await physics_frame;await physics_frame
	actor.position=a;actor.state=actor.State.SEARCH;actor.search_remaining=4;actor.think_timer=0
	await create_timer(.35).timeout
	check(actor.state==actor.State.CHASE,"rediscovery resumes pursuit")
	actor.position=a;actor.home=a-Vector2(1000,0);actor.state=actor.State.CHASE;actor.think_timer=0
	await create_timer(.35).timeout
	check(actor.state==actor.State.RETREAT,"pursuit leash prevents whole-region chase")
	actor.home=a;actor.position=b;actor.ignore_until=s.forest_encounters.clock+10
	actor.state=actor.State.RETREAT;actor.think_timer=0;actor.path.clear()
	var distance:float=actor.position.distance_to(a)
	await create_timer(.6).timeout
	check(actor.position.distance_to(a)<distance and actor.ignore_until>s.forest_encounters.clock,"fled actor physically retreats under cooldown")
	var shape:=PhysicsShapeQueryParameters2D.new()
	shape.shape=actor.get_node("CollisionShape2D").shape;shape.transform=actor.global_transform;shape.collision_mask=1
	check(w.get_world_2d().direct_space_state.intersect_shape(shape).is_empty(),"moving actor remains outside solid terrain")
	actor.queue_free();await process_frame
	director.actors.clear();s.forest_encounters.population.clear()
	w.player.position=b
	director.set_process(true)
	await create_timer(4).timeout
	check(s.forest_encounters.population.size()>=2 and s.forest_encounters.population.size()<=4,"bounded nearby population spawns")
	for id in s.forest_encounters.population:
		var slot:Dictionary=s.forest_encounters.population[id]
		check(nav.valid(slot.home) and not director.safe(slot.home),"spawn respects collision grid and safe zones")
	for enemy in director.actors:
		if is_instance_valid(enemy):enemy.set_physics_process(false)
	var count:int=s.forest_encounters.population.size()
	for slot in s.forest_encounters.population.values():slot.alive=false
	await create_timer(2).timeout
	check(s.forest_encounters.population.size()==count,"defeated slots never replenished during visit")
	# Actual body contact uses the shared transition and correct sprite identity.
	if s.forest_encounters.population.has(0):
		var data_contact:Dictionary=s.forest_encounters.population[0]
		data_contact.alive=true
		data_contact.position=w.player.position
		var contact=director.spawn_actor(0,data_contact)
		s.forest_encounters.population[contact.encounter_id].alive=true
		contact.set_physics_process(true)
		contact.position=w.player.position
		contact.ignore_until=0
		s.forest_encounters.protection_until=0
		var id:int=contact.kind
		await create_timer(.15).timeout
		while s.busy:await process_frame
		check(current_scene.has_method("finish_entry") and current_scene.battle.kind==id,"physical contact starts correct ordinary fight")
		current_scene.battle.finish("flee")
		await process_frame
		while s.busy:await process_frame
		check(current_scene.name=="Overworld" and s.forest_encounters.protection_until>s.forest_encounters.clock,"contact flow returns with protection")
	print("FOREST AI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
