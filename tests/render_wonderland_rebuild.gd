extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
var output="/workspace/.catsSaga-validation/wonderland-rebuild/render"
func _initialize() -> void:run.call_deferred()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 for id in Layout.regions():
  var map=load("res://scenes/wonderland/"+id+".tscn").instantiate()
  var viewport:=SubViewport.new();viewport.disable_3d=true;viewport.world_2d=World2D.new()
  viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
  viewport.size=Vector2i(map.map_size/2) if Layout.OUTDOORS.has(id) else Vector2i(1280,960)
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(viewport);viewport.add_child(map)
  var camera:=Camera2D.new();camera.position=map.map_size*.5;camera.zoom=Vector2.ONE*.5 if Layout.OUTDOORS.has(id) else Vector2.ONE
  viewport.add_child(camera);camera.make_current();camera.force_update_scroll()
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image();assert(not image.is_empty());image.save_png(output.path_join(id+".png"))
  if Layout.OUTDOORS.has(id):
   await create_timer(.6).timeout;await RenderingServer.frame_post_draw
   assert(image.get_data()!=viewport.get_texture().get_image().get_data(),id+" environment visibly animates")
   viewport.size=Vector2i(1280,720);camera.zoom=Vector2.ONE
   camera.position={"wonderland_forest":Vector2(1280,840),"tea_gardens":Vector2(650,1200),"mushroom_thicket":Vector2(1700,700),"royal_woods":Vector2(2850,900),"wonderland_village":Vector2(1472,600),"queens_castle":Vector2(1280,900)}[id]
   camera.force_update_scroll();await process_frame;await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(output.path_join(id+"-detail.png"))
  print("RENDERED ",id)
  viewport.queue_free();await process_frame
 quit()
