extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
var checks:=0
var failures:=0
var walked:=0.0
var output="/workspace/.catsSaga-validation/wonderland-v2/navigation"
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func clear(map:Node2D,point:Vector2,probe:PhysicsShapeQueryParameters2D) -> bool:
 probe.transform=Transform2D(0,point)
 return map.is_walkable_position(point) and map.get_world_2d().direct_space_state.intersect_shape(probe,1).is_empty()
func capture(name:String,point:Vector2) -> void:
 if DisplayServer.get_name()=="headless":return
 var camera:Camera2D=current_scene.player.get_node("Camera2D");camera.global_position=point;camera.force_update_scroll()
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
 var session=root.get_node("Session");session.story_flags["wonderland_arrived"]=true;session.story_flags["wonderland_intro_completed"]=true
 for id in Layout.regions():
  var packed=load("res://scenes/wonderland/"+id+".tscn");var temp=packed.instantiate();var entry:String=temp.get_node("Entries").get_child(0).name;temp.free()
  await session.travel(id,entry)
  var world=current_scene;var map=world.map;var player=world.player
  session.busy=true # Suppress travel while the real body exercises each route's collision.
  var probe:=PhysicsShapeQueryParameters2D.new();probe.shape=player.get_node("CollisionShape2D").shape;probe.collision_mask=1;probe.exclude=[player.get_rid()]
  if id=="queens_castle":session.story_flags[Layout.CASTLE_OPEN]=true;await process_frame;await process_frame;await physics_frame;await physics_frame
  var grid:=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,Vector2i(map.map_size/32));grid.cell_size=Vector2(32,32);grid.offset=Vector2(16,16);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
  for y in grid.region.size.y:
   for x in grid.region.size.x:
    if not clear(map,Vector2(x*32+16,y*32+16),probe):grid.set_point_solid(Vector2i(x,y),true)
  var start:=Vector2i(player.position/32);var route_count:=0
  for portal in map.get_node("Portals").get_children():
   if portal.destination=="flooded_forest":continue
   var target:=Vector2i(portal.position/32).clamp(Vector2i.ZERO,grid.region.size-Vector2i.ONE);var points:=grid.get_point_path(start,target)
   check(not points.is_empty(),id+" route exists "+str(portal.name))
   if points.is_empty():continue
   player.position=points[0];var collision:=false;var steps:=0
   for i in range(1,points.size()):
    var remaining:Vector2=points[i]-player.position
    while remaining.length()>.01:
     var motion:Vector2=remaining.limit_length(8);var hit=player.move_and_collide(motion)
     if hit!=null:collision=true;break
     walked+=motion.length();remaining=points[i]-player.position;steps+=1
     if steps%128==0:await physics_frame
    if collision:break
    if i==points.size()/2 and route_count<2:await capture(id+"-route-"+str(route_count),player.position)
   check(not collision and player.position.distance_to(points[-1])<1,id+" real-body traversal "+str(portal.name))
   route_count+=1
  if Layout.OUTDOORS.has(id):
   var tested:=false
   for tree in get_nodes_in_group("wonderland_environment_props"):
    if tree.kind!="tree" or not map.is_ancestor_of(tree):continue
    var point:Vector2=tree.global_position-Vector2(0,70)
    if not clear(map,point,probe):continue
    player.position=point;await create_timer(.45).timeout
    check(tree.self_modulate.a<.5,id+" foreground tree fades locally")
    await capture(id+"-foliage-fade",point)
    player.position=map.get_node("Entries").get_child(0).position;await create_timer(.45).timeout
    check(tree.self_modulate.a>.98,id+" tree opacity restores")
    tested=true;break
   check(tested,id+" foliage occlusion tested")
  print("NAVIGATED ",id," routes=",route_count)
  session.busy=false;session.story_flags.erase(Layout.CASTLE_OPEN)
 print("NAVIGATION: ",checks," checks, ",failures," failures, ",roundi(walked)," world pixels traversed with move_and_collide")
 quit(1 if failures else 0)
