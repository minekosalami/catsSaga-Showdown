extends Node2D
## Animate human atlas art with transforms only; no generated particle artwork.
@export var indoor := false
var clock := 0.0
var ornaments: Array[Node2D] = []
var accumulator := 0.0
var leaves: CPUParticles2D
var waves: Array[Sprite2D] = []
func _ready() -> void:
 if not indoor:
  leaves = CPUParticles2D.new()
  leaves.name = "FallingPetals"
  leaves.texture = preload("res://assets/wonderland_human/ninja/particle_leaf_pink.png")
  var flutter := CanvasItemMaterial.new()
  flutter.particles_animation = true
  flutter.particles_anim_h_frames = 6
  flutter.particles_anim_v_frames = 1
  flutter.particles_anim_loop = true
  leaves.material = flutter
  leaves.anim_speed_min = .35
  leaves.anim_speed_max = .65
  leaves.anim_offset_max = 1
  leaves.amount = 70
  leaves.lifetime = 18
  leaves.preprocess = 12
  leaves.position = get_parent().map_size*.5
  leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
  leaves.emission_rect_extents = get_parent().map_size*.5
  leaves.direction = Vector2(1,1)
  leaves.spread = 20
  leaves.gravity = Vector2(1,5)
  leaves.initial_velocity_min = 6
  leaves.initial_velocity_max = 12
  leaves.scale_amount_min = .55
  leaves.scale_amount_max = 1.1
  leaves.angular_velocity_min = -40
  leaves.angular_velocity_max = 40
  leaves.modulate.a = .6
  add_child(leaves)
  var water := get_parent().get_node_or_null("FairytaleWater") as TileMapLayer
  if water != null:
   var cells := water.get_used_cells()
   var ink := ShaderMaterial.new()
   ink.shader = preload("res://shaders/human_icon_mask.gdshader")
   for i in range(12):
    var cell: Vector2i = cells[(i*37)%cells.size()]
    var wave := Sprite2D.new()
    wave.texture = preload("res://assets/movement_human/echo-ripples.svg")
    wave.position = water.map_to_local(cell)*water.scale
    wave.scale = Vector2(18,6)/512.0
    wave.material = ink
    wave.modulate = Color(1,1,1,.16)
    wave.z_index = -5
    get_parent().add_child.call_deferred(wave)
    waves.append(wave)
 for node in get_tree().get_nodes_in_group("wonderland_ornaments"):
  if get_parent().is_ancestor_of(node) and node.kind in ["flowers","roses","giant_flower","fountain","teapot","mushroom"]:ornaments.append(node)
func _process(delta: float) -> void:
 clock += delta
 for i in waves.size():
  waves[i].modulate.a = .07+.06*sin(clock*.7+i)
  waves[i].scale = Vector2(18+sin(clock*.7+i)*3,6)/512.0
 accumulator += delta
 if accumulator < .083:return
 accumulator = 0
 for node in ornaments:
  if not get_viewport_rect().grow(300).has_point(get_canvas_transform()*node.global_position):continue
  if node.kind in ["flowers","roses","giant_flower"]:node.rotation = sin(clock*.8+node.position.x*.01)*.018
  if node.kind == "fountain":node.modulate = Color.WHITE.lerp(Color("#d4f6ff"),.25+.12*sin(clock*2))
  node.tick(clock)
