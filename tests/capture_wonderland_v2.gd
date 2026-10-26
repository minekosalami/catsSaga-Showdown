extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
var out:String
var stats:Dictionary={}
var cameras:Dictionary={}
func _initialize() -> void:run.call_deferred()
func shot(name:String,point:Vector2) -> void:
 var world=current_scene;world.player.velocity=Vector2.ZERO
 var probe:=PhysicsShapeQueryParameters2D.new();probe.shape=world.player.get_node("CollisionShape2D").shape;probe.collision_mask=1;probe.exclude=[world.player.get_rid()]
 var legal:=point
 for radius in [0,64,128,192,256,320]:
  var found:=false
  for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
   var p:Vector2=point+direction*radius;probe.transform=Transform2D(0,p)
   if world.map.is_walkable_position(p) and world.get_world_2d().direct_space_state.intersect_shape(probe,1).is_empty():legal=p;found=true;break
  if found:break
 world.player.position=legal
 if not Layout.OUTDOORS.has(world.map.region_id) and not name.ends_with("-upper"):point=Vector2(640,480)
 var camera:Camera2D=world.player.get_node("Camera2D");camera.set_process(false);camera.followed=point;camera.lead=Vector2.ZERO;camera.global_position=point;camera.force_update_scroll()
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
 cameras[name]={"center":var_to_str(camera.get_screen_center_position()),"zoom":var_to_str(camera.zoom),"image_size":var_to_str(root.size)}
func run() -> void:
 var phase:String="before" if OS.get_cmdline_user_args().has("--before") else "after"
 out="/workspace/.catsSaga-validation/wonderland-v2/"+phase+("-1920" if OS.get_cmdline_user_args().has("--large") else "");DirAccess.make_dir_recursive_absolute(out)
 if FileAccess.file_exists(out.path_join("performance.json")):stats=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("performance.json")))
 root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280,720);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var session=root.get_node("Session");session.story_flags["wonderland_arrived"]=true;session.story_flags["wonderland_intro_completed"]=true
 var spots={"wonderland_forest":[Vector2(1100,1060),Vector2(400,550)],"tea_gardens":[Vector2(690,1460),Vector2(1600,800)],"mushroom_thicket":[Vector2(1700,800),Vector2(1900,400)],"royal_woods":[Vector2(3060,900),Vector2(2200,1050)],"wonderland_village":[Vector2(1472,600),Vector2(2400,820)],"queens_castle":[Vector2(1280,1040),Vector2(580,1250)]}
 for id in Layout.regions():
  if OS.get_cmdline_user_args().has("--buildings") and id!="wonderland_village":continue
  if OS.get_cmdline_user_args().has("--storyteller") and id!="storytellers_cottage":continue
  if OS.get_cmdline_user_args().has("--outdoors") and not Layout.OUTDOORS.has(id):continue
  if OS.get_cmdline_user_args().has("--interiors") and Layout.OUTDOORS.has(id):continue
  if OS.get_cmdline_user_args().has("--large") and id not in ["wonderland_village","queens_castle","teapot_house","throne_room"]:continue
  var map=load("res://scenes/wonderland/"+id+".tscn").instantiate();var entry:String=map.get_node("Entries").get_child(0).name;map.free()
  await session.travel(id,entry)
  if OS.get_cmdline_user_args().has("--large"):root.size=Vector2i(1920,1080)
  if OS.get_cmdline_user_args().has("--buildings"):
   for building in Layout.BUILDINGS:await shot("entrance-"+building.id,building.point+Vector2(0,100))
  if Layout.OUTDOORS.has(id):
   for i in 2:await shot(id+"-"+str(i),spots[id][i])
  else:
   await shot(id,Vector2(640,565))
   if id in ["throne_room","teapot_house"]:await shot(id+"-upper",Vector2(640,360))
  var times:Array[float]=[];var prev:=Time.get_ticks_usec()
  for i in 90:
   await process_frame;var now:=Time.get_ticks_usec();times.append((now-prev)/1000.0);prev=now
  times.sort();stats[id]={"median_ms":times[45],"p95_ms":times[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
  print("CAPTURE ",phase," ",id)
 var file:=FileAccess.open(out.path_join("performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(stats,"\t"))
 file=FileAccess.open(out.path_join("cameras.json"),FileAccess.WRITE);file.store_string(JSON.stringify(cameras,"\t"));quit()
