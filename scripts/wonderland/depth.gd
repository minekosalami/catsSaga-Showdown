extends Node2D
## Static directional silhouettes use the original human art, never new textures.
var trees:Array[Sprite2D]=[]
var player:Node2D
var elapsed:=0.0
var faded:Dictionary={}
var fade_tweens:Dictionary={}
func _ready() -> void:install.call_deferred()
func install() -> void:
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/wonderland_shadow.gdshader")
 material.set_shader_parameter("opacity",.15 if not get_parent().get_node("WonderlandAmbience").indoor else .12)
 var props=get_tree().get_nodes_in_group("wonderland_environment_props")+get_tree().get_nodes_in_group("wonderland_ornaments")
 for art in props:
  if not get_parent().is_ancestor_of(art) or art.get_meta("depth_shadow",false):continue
  if art is Sprite2D and art.kind in ["tree","mushroom"]:trees.append(art)
  if art.kind in ["flowers","rug","window","leaf_litter","wall_background","wall"]:continue
  var shadow:Node2D
  if art is Sprite2D:
   shadow=Sprite2D.new();shadow.texture=art.texture;shadow.offset=art.offset
  else:
   shadow=load("res://scripts/wonderland/ornament.gd").new();shadow.kind=art.kind;shadow.variant=art.variant;shadow.footprint=art.footprint;shadow.visual_offset=art.visual_offset;shadow.set_meta("depth_shadow",true)
  shadow.name="Grounded_"+str(art.name);shadow.position=get_parent().to_local(art.global_position);shadow.scale=art.global_scale
  shadow.z_index=-4;shadow.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(shadow);shadow.material=material
 var actors=get_tree().get_nodes_in_group("overworld_player")
 if not actors.is_empty():player=actors[0]
 # Signs are installed after the map's _ready; their visual child shares this system.
 for sign in get_tree().get_nodes_in_group("destination_signs"):
  if get_parent().is_ancestor_of(sign):
   for art in sign.get_children():
    if art is Sprite2D:
     var shadow:=Sprite2D.new();shadow.texture=art.texture;shadow.position=get_parent().to_local(sign.global_position);shadow.offset=Vector2(0,-8);shadow.scale=art.scale;shadow.z_index=-4;shadow.material=material;add_child(shadow)
func _process(delta:float) -> void:
 elapsed+=delta
 if elapsed<.08 or not is_instance_valid(player):return
 elapsed=0
 var view:=get_viewport_rect().grow(320)
 var canvas:=get_canvas_transform()
 for art in trees:
  if not bool(faded.get(art,false)) and not view.has_point(canvas*art.global_position):continue
  var rect:Rect2=art.get_rect();rect.size.y=maxf(0,rect.size.y-18)
  var point:Vector2=player.global_position-Vector2(0,24)
  var obstruction:bool=player.global_position.y<art.global_position.y and rect.has_point(art.to_local(point))
  if obstruction==bool(faded.get(art,false)):continue
  faded[art]=obstruction
  if fade_tweens.has(art) and is_instance_valid(fade_tweens[art]):fade_tweens[art].kill()
  var tween=create_tween();fade_tweens[art]=tween;tween.tween_property(art,"self_modulate:a",.38 if obstruction else 1.0,.22)

func _exit_tree() -> void:
 for tween in fade_tweens.values():
  if is_instance_valid(tween):tween.kill()
 fade_tweens.clear();faded.clear();trees.clear();player=null
