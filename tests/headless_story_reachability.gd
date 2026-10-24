extends SceneTree
var failures:=0
func _initialize():
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	run.call_deferred()
func run():
	var session=root.get_node("Session")
	session.story_flags["blankkitten_defeated"]=true
	var content=load("res://scripts/story/world_content.gd")
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		await session.travel(area,"Start")
		var world=current_scene
		await physics_frame;await physics_frame
		var q:=PhysicsShapeQueryParameters2D.new()
		q.shape=world.player.get_node("CollisionShape2D").shape
		q.collision_mask=1
		var space=world.get_world_2d().direct_space_state
		var points: Array=[]
		for item in content.FEATHERS[area]:points.append([item[0],item[1]])
		for star in load("res://scripts/world/save_statue.gd").LOCATIONS[area]:points.append(["save",star+Vector2(0,54)])
		if area=="entrance":points.append(["Butterscotch",content.BUTTERSCOTCH_POSITION+Vector2(0,60)])
		if area=="deep_forest":
			points.append(["Cupid",content.CUPID_POSITION+Vector2(0,60)])
			points.append(["Shop",content.SHOP_POSITION+Vector2(0,64)])
		if area=="flooded_forest":points.append(["Doppelcat",Vector2(1936,850)])
		var size:Vector2=world.map.map_size
		var origin:Vector2=world.map.get_node("Entries/Start").position
		var queue: Array[Vector2i]=[Vector2i.ZERO]
		var visited={Vector2i.ZERO:true}
		var reachable={Vector2i.ZERO:true}
		var cursor:=0
		while cursor<queue.size():
			var cell=queue[cursor];cursor+=1
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next:Vector2i=cell+direction
				if visited.has(next):continue
				visited[next]=true
				var point:Vector2=origin+Vector2(next)*32
				if not Rect2(Vector2(48,48),size-Vector2(96,96)).has_point(point):continue
				q.transform=Transform2D(0,point)
				if not space.intersect_shape(q,1).is_empty():continue
				queue.append(next);reachable[next]=true
			if cursor%1000==0:await process_frame
		for item in points:
			q.transform=Transform2D(0,item[1])
			var clear=space.intersect_shape(q,1).is_empty() and world.map.is_walkable_position(item[1])
			var close=false
			var cell:Vector2i=Vector2i(((item[1]-origin)/32).round())
			for dy in range(-1,2):
				for dx in range(-1,2):
					var candidate=cell+Vector2i(dx,dy)
					if not reachable.has(candidate):continue
					q.motion=origin+Vector2(candidate)*32-item[1]
					if space.cast_motion(q)[0]>=1:close=true
			q.motion=Vector2.ZERO
			if not clear or not close:failures+=1
			print("REACH ",area," ",item[0]," ",item[1]," clear=",clear," connected=",close)
	print("REACHABILITY failures: ",failures)
	quit(1 if failures else 0)
