extends SceneTree
## Cartography captures actual human artwork; no painted map backgrounds/icons.
const Plan = preload("res://scripts/wonderland/layout.gd")
const Builder = preload("res://scripts/wonderland/builder.gd")
var atlases: Dictionary = {}
func _initialize() -> void:call_deferred("run")
func cartography(id: String,map: Node2D) -> void:
 var group: String = Plan.group(id)
 if not atlases.has(group):
  var size := Plan.extent(id)
  var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
  image.fill(Color.TRANSPARENT)
  atlases[group] = image
 var region: Dictionary = Plan.regions()[id]
 var viewport := SubViewport.new()
 viewport.size = region.size
 viewport.disable_3d = true
 viewport.transparent_bg = true
 viewport.world_2d = World2D.new()
 viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 viewport.add_child(map)
 var camera := Camera2D.new()
 camera.position = map.map_size/2
 camera.zoom = Vector2.ONE/16
 viewport.add_child(camera)
 camera.make_current()
 camera.force_update_scroll()
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var frame := viewport.get_texture().get_image()
 if frame.is_empty():push_error("Empty rendered map: "+id);quit(1);return
 frame.convert(Image.FORMAT_RGBA8)
 atlases[group].blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),region.offset)
 viewport.queue_free()
 await process_frame
func run() -> void:
 var maps_only := OS.get_cmdline_user_args().has("--maps-only")
 if FileAccess.file_exists("res://scenes/wonderland/wonderland_forest.tscn") and not OS.get_cmdline_user_args().has("--rebuild") and not maps_only:
  push_error("Wonderland already exists. Edit scenes directly; -- --rebuild explicitly replaces authored maps.");quit(1);return
 if DisplayServer.get_name() == "headless":
  push_error("Use a graphical display for atlas-only rendered cartography. --maps-only never changes scenes.");quit(1);return
 var builder := Builder.new()
 if not maps_only:builder.setup_tiles()
 for id in Plan.regions():
  var map: Node2D = load("res://scenes/wonderland/"+id+".tscn").instantiate() if maps_only else builder.build(id)
  if not maps_only:
   var packed := PackedScene.new()
   if packed.pack(map)!=OK or ResourceSaver.save(packed,"res://scenes/wonderland/"+id+".tscn")!=OK:
    push_error("Could not save scene: "+id);quit(1);return
  await cartography(id,map)
  print("CAPTURED MAP ",id)
 for group in atlases:
  var texture := ImageTexture.create_from_image(atlases[group])
  if ResourceSaver.save(texture,"res://resources/maps/"+group+"_terrain.res",ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
 quit()
