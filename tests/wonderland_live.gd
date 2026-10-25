extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
var session:Node
var checks:=0
var failures:=0
var capture:=false
var output:="/workspace/.catsSaga-validation/wonderland-rebuild/live"
var performance:Dictionary={}
func _initialize() -> void:
 create_timer(240).timeout.connect(func():push_error("LIVE TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func screenshot(name:String) -> void:
 if not capture:return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func settle() -> void:
 for i in 500:
  if not session.busy:break
  await create_timer(.01).timeout
 await physics_frame;await physics_frame
func inspect_region(id:String) -> void:
 print("LIVE ",id)
 check(session.area_id==id and current_scene.map.region_id==id,"Live region "+id)
 check(current_scene.encounters==null,"No encounter director in "+id)
 check(not current_scene.dialogue.active,"No new dialogue in "+id)
 var ambience=current_scene.map.get_node("WonderlandAmbience")
 check(ambience.leaves!=null if Layout.OUTDOORS.has(id) else ambience.leaves==null,"Region particles "+id)
 if capture:
  await create_timer(.4).timeout
  await screenshot(id)
  if Layout.OUTDOORS.has(id):
   var points:Dictionary={"wonderland_forest":Vector2(1100,1060),"tea_gardens":Vector2(690,1460),"mushroom_thicket":Vector2(1700,800),"royal_woods":Vector2(3060,900),"wonderland_village":Vector2(1472,600),"queens_castle":Vector2(1280,1040)}
   current_scene.player.position=points[id]
   var camera:Camera2D=current_scene.player.get_node("Camera2D");camera.reset_smoothing();camera.force_update_scroll()
   await create_timer(.4).timeout;await screenshot(id+"-landmark")
   var times:Array[float]=[];var previous:=Time.get_ticks_usec()
   for i in 150:
    await process_frame
    var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
   times.sort()
   performance[id]={"median_frame_ms":times[75],"p95_frame_ms":times[142],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
func run() -> void:
 capture=DisplayServer.get_name()!="headless";DirAccess.make_dir_recursive_absolute(output)
 if capture:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size=Vector2i(1280,720);session=root.get_node("Session")
 session.story_flags["wonderland_arrived"]=true;session.story_flags["wonderland_intro_completed"]=true
 await session.travel("wonderland_forest","FromFlooded")
 await inspect_region("wonderland_forest")
 var music:=root.get_node("Music");var music_id:int=music.player.get_instance_id();var music_pos:float=music.player.get_playback_position()
 var portal=current_scene.map.get_node("Portals/To_tea_gardens")
 current_scene.player.position=portal.position
 await physics_frame;await physics_frame
 await create_timer(.8).timeout
 check(session.curtain.material!=null,"Storybook wipe active during physical seam crossing")
 await screenshot("storybook-transition")
 await settle()
 check(session.area_id=="tea_gardens","Area2D crossing enters Tea Gardens")
 check(music.player.get_instance_id()==music_id and music.player.get_playback_position()>music_pos,"Continuous soundtrack across storybook transition")
 check(not session.curtain.visible and session.curtain.material==null,"Transition cleans up")
 if OS.get_cmdline_user_args().has("--transition-only"):quit(1 if failures else 0);return
 for id in Layout.regions():
  var map=load("res://scenes/wonderland/"+id+".tscn").instantiate()
  var marker:String=map.get_node("Entries").get_child(0).name;map.free()
  await session.travel(id,marker)
  await inspect_region(id)
  if OS.get_cmdline_user_args().has("--visual-only"):continue
  var destinations:Array=[]
  for connection in current_scene.map.get_node("Portals").get_children():
   if connection.destination in Layout.regions() and connection.can_travel():destinations.append([str(connection.name),connection.destination,connection.entry])
  # Exercise the existing connected signal callback for every available door.
  for dest in destinations:
   var connection=current_scene.map.get_node("Portals/"+dest[0])
   connection._on_body_entered(current_scene.player)
   await settle()
   check(session.area_id==dest[1] and session.entry_marker==dest[2],id+" -> "+dest[1]+" existing connection")
   await session.travel(id,marker)
  if id=="queens_castle":
   var gate=current_scene.map.get_node("CastleGate")
   check(not gate.open_now(),"Castle still locked")
   check(not current_scene.map.get_node("Portals/CastleEntrance").can_travel(),"Castle entry still gated")
   gate.handle_interaction(current_scene)
   check(not gate.open_now(),"Interaction does not invent unlock")
 if OS.get_cmdline_user_args().has("--visual-only"):
  var file:=FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(performance,"\t"))
  print("WONDERLAND VISUAL: ",checks," checks, ",failures," failures");quit(1 if failures else 0);return
 # Saved positions inside new scenery must migrate safely using the existing loader.
 var old=session.snapshot("teapot_house",Vector2(100,100))
 check(session.saves.write_save(old),"Write legacy-position fixture")
 check(session.saves.write_progress(old),"Write matching fixture progress")
 check(await session.load_game(session.active_slot),"Existing save loader")
 await create_timer(.2).timeout
 var expected:Vector2=current_scene.map.get_node("Entries").get_child(0).position
 check(current_scene.player.position==expected,"Obstructed saved position recovers at original doorway")
 check(session.story_flags.get("wonderland_intro_completed",false),"Intro completion survives load")
 check(not session.save_current(),"Saving away from manual save point remains forbidden")
 await session.travel("wonderland_forest","FromFlooded")
 var amb=current_scene.map.get_node("WonderlandAmbience")
 root.get_node("VisualSettings").reduced=true;await create_timer(.2).timeout
 check(not amb.leaves.emitting,"Reduced-motion disables drifting particles")
 root.get_node("Ambience").enabled=false
 await create_timer(1.6).timeout
 check(amb.audio_fade==0.0,"Ambience mute fades positional layer")
 if capture:
  var file:=FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(performance,"\t"))
 print("WONDERLAND LIVE: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
