extends Node2D
## Shared shaders and culled transform updates animate credited atlas artwork.
@export var indoor := false
var clock := 0.0
var accumulator := 0.0
var ornaments: Array[Node2D] = []
var signs: Array[Sprite2D] = []
var clocks: Array[Sprite2D] = []
var leaves: CPUParticles2D
var foliage: ShaderMaterial
var flowers: ShaderMaterial
var mushrooms: ShaderMaterial
var drift_material: ShaderMaterial
var sound_points: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer2D] = []
var rng := RandomNumberGenerator.new()
var next_sound := 3.0
var fountain: AudioStreamPlayer2D
var audio_fade := 0.0
func _ready() -> void:
 rng.randomize()
 foliage=ShaderMaterial.new();foliage.shader=preload("res://shaders/wonderland_foliage.gdshader")
 flowers=foliage.duplicate();flowers.set_shader_parameter("height",32.0);flowers.set_shader_parameter("strength",.5)
 mushrooms=ShaderMaterial.new();mushrooms.shader=preload("res://shaders/wonderland_mushroom.gdshader")
 for node in get_tree().get_nodes_in_group("wonderland_environment_props"):
  if get_parent().is_ancestor_of(node) and node.animate:
   if node.kind=="tree":node.material=foliage
   elif node.kind=="mushroom":node.material=mushrooms
   elif node.kind=="flowers":node.material=flowers
   elif node.kind=="clock":clocks.append(node)
 var drifts:=get_parent().get_node_or_null("FlowerDrifts") as TileMapLayer
 if drifts!=null:
  drift_material=flowers.duplicate();drift_material.set_shader_parameter("tile_motion",true);drifts.material=drift_material
 for node in get_tree().get_nodes_in_group("wonderland_ornaments"):
  if not get_parent().is_ancestor_of(node):continue
  if node.kind in ["flowers","roses","giant_flower","fountain","teapot","mushroom","banner","lantern"]:ornaments.append(node)
  if node.kind=="fountain" and fountain==null:
   fountain=voice_at(node.position,preload("res://assets/ambience_human/small_waterfall.ogg"));fountain.volume_db=-80;fountain.play()
  if node.kind in ["tea_table","grand_teacup","grand_teapot"]:sound_points.append({"point":node.position,"clip":preload("res://assets/wonderland_human/rebuild/audio/glass_clink.ogg")})
  elif node.kind in ["banner","clock_house","teapot_house","house"]:sound_points.append({"point":node.position,"clip":preload("res://assets/weather_human/wood_creak.ogg")})
 if not indoor:
  leaves=CPUParticles2D.new();leaves.name="DriftingPetals"
  leaves.texture=preload("res://assets/wonderland_human/ninja/particle_leaf_pink.png")
  var flutter:=CanvasItemMaterial.new();flutter.particles_animation=true;flutter.particles_anim_h_frames=6;flutter.particles_anim_loop=true
  leaves.material=flutter;leaves.anim_speed_min=.35;leaves.anim_speed_max=.65;leaves.anim_offset_max=1
  leaves.amount=42;leaves.lifetime=12;leaves.preprocess=8
  leaves.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;leaves.emission_rect_extents=Vector2(720,450)
  leaves.direction=Vector2(.6,1);leaves.spread=35;leaves.gravity=Vector2(1,2)
  leaves.initial_velocity_min=7;leaves.initial_velocity_max=16;leaves.scale_amount_min=.6;leaves.scale_amount_max=1.2
  leaves.angular_velocity_min=-32;leaves.angular_velocity_max=32;leaves.modulate.a=.65;leaves.local_coords=false
  if get_parent().region_id=="mushroom_thicket":
   leaves.modulate=Color(.65,1,1,.5);leaves.scale_amount_min=.25;leaves.scale_amount_max=.6;leaves.gravity=Vector2(1,-3);leaves.direction=Vector2.UP
  add_child(leaves)
 collect_signs.call_deferred()
func collect_signs() -> void:
 for sign in get_tree().get_nodes_in_group("destination_signs"):
  if get_parent().is_ancestor_of(sign):
   for child in sign.get_children():
    if child is Sprite2D:signs.append(child)
func voice_at(point:Vector2,clip:AudioStream) -> AudioStreamPlayer2D:
 var voice:=AudioStreamPlayer2D.new();voice.stream=clip;voice.position=point;voice.bus="Ambience";voice.max_distance=700;voice.attenuation=1.5;voice.volume_db=-32
 add_child(voice);return voice
func _process(delta:float) -> void:
 clock+=delta;accumulator+=delta
 var visual=get_node("/root/VisualSettings")
 var motion:float=0 if visual.reduced else visual.motion
 foliage.set_shader_parameter("motion",motion);flowers.set_shader_parameter("motion",motion);mushrooms.set_shader_parameter("motion",motion)
 if drift_material!=null:drift_material.set_shader_parameter("motion",motion)
 var camera:=get_viewport().get_camera_2d()
 if leaves!=null:
  leaves.emitting=motion>.01
  if camera!=null:leaves.global_position=camera.get_screen_center_position()
 var ambience=get_node("/root/Ambience")
 var session=get_node("/root/Session")
 audio_fade=move_toward(audio_fade,1.0 if ambience.enabled and not session.busy else 0.0,delta/1.4)
 if fountain!=null:
  fountain.volume_db=-23+linear_to_db(maxf(.0001,audio_fade))
  if not fountain.playing:fountain.play()
 if clock>=next_sound:
  next_sound=clock+rng.randf_range(12,27)
  for i in range(voices.size()-1,-1,-1):
   if not voices[i].playing:voices[i].queue_free();voices.remove_at(i)
  var nearby:Array[Dictionary]=[]
  for point in sound_points:
   if get_viewport_rect().grow(100).has_point(get_canvas_transform()*to_global(point.point)):nearby.append(point)
  if audio_fade>.9 and not nearby.is_empty() and voices.size()<2:
   var point:Dictionary=nearby[rng.randi_range(0,nearby.size()-1)]
   var voice:=voice_at(point.point,point.clip);voice.pitch_scale=rng.randf_range(.96,1.04);voice.play();voices.append(voice)
 for voice in voices:voice.volume_db=-32+linear_to_db(maxf(.0001,audio_fade))
 if accumulator<.083:return
 accumulator=0
 for clock_art in clocks:
  if not get_viewport_rect().grow(100).has_point(get_canvas_transform()*clock_art.global_position):continue
  var frame:int=int(clock*2*motion+clock_art.position.x*.017)%3
  clock_art.texture.region=Rect2(frame*32,0,32,96)
 for sign in signs:
  if is_instance_valid(sign) and get_viewport_rect().grow(100).has_point(get_canvas_transform()*sign.global_position):sign.rotation=sin(clock*.75+sign.global_position.x*.01)*.014*motion
 for node in ornaments:
  if not get_viewport_rect().grow(300).has_point(get_canvas_transform()*node.global_position):continue
  var phase:float=node.position.x*.017+node.position.y*.023
  if node.kind in ["flowers","roses","giant_flower","banner"]:node.rotation=sin(clock*(.7+fmod(phase,.4))+phase)*.016*motion
  if node.kind=="fountain":
   node.modulate=Color.WHITE.lerp(Color("#bdeeff"),.18+.08*sin(clock*2+phase)*motion)
   node.material.set_shader_parameter("motion",motion)
  if node.kind=="lantern":node.modulate=Color.WHITE.lerp(Color("#fff0c0"),.1+.07*sin(clock*1.8+phase)*motion)
  node.tick(clock*motion+phase)

func _exit_tree() -> void:
 for child in get_children():
  if child is AudioStreamPlayer2D:child.stop();child.stream=null
