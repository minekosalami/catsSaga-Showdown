extends Node2D
## Cosmetic child offsets only; movement, collision and controls stay on the player.
const SHADOW = preload("res://assets/wonderland_human/ninja/Shadow.png")
const RIPPLE = preload("res://assets/movement_human/echo-ripples.svg")
const PAW = preload("res://assets/movement_human/paw-print.svg")
var sprite: Sprite2D
var rest_offset := Vector2.ZERO
var shadow: Sprite2D
var clock := 0.0
var step_distance := 0.0
var previous := Vector2.ZERO
var prints: Array[Dictionary] = []
var foot := 0
var ink_material: ShaderMaterial
var water_point := Vector2.ZERO
var water_nearby := false
var sample_clock := 0.0
var water_map_id := 0
var water_layers: Array[Node] = []
var rest_scale := Vector2.ONE
func _ready() -> void:
 ink_material = ShaderMaterial.new()
 ink_material.shader = preload("res://shaders/human_icon_mask.gdshader")
 sprite = get_parent().sprite
 rest_offset = sprite.offset
 rest_scale = sprite.scale
 preload("res://scripts/ui/pixel_art.gd").apply(sprite)
 previous = get_parent().global_position
 z_index = -1
 shadow = Sprite2D.new()
 shadow.texture = SHADOW
 shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 shadow.position = Vector2(0,24)
 shadow.scale = Vector2(3.2,1.2)
 shadow.modulate = Color(1,1,1,.52)
 add_child(shadow)
func _exit_tree() -> void:
 for item in prints:
  if is_instance_valid(item.sprite):item.sprite.queue_free()
func sample_water() -> bool:
 var world := get_parent().get_parent()
 if world.get("map") == null:return false
 if water_map_id!=world.map.get_instance_id():
  water_map_id = world.map.get_instance_id()
  water_layers = world.map.find_children("*Water*","TileMapLayer",true,false)
 for layer in water_layers:
  for offset in [Vector2.ZERO,Vector2(32,0),Vector2(-32,0),Vector2(0,32),Vector2(0,-32)]:
   var cell: Vector2i = layer.local_to_map(layer.to_local(get_parent().global_position+offset))
   if layer.get_cell_source_id(cell)>=0:
    water_point = layer.to_global(layer.map_to_local(cell))
    return true
 return false
func _process(delta: float) -> void:
 var actor := get_parent()
 var distance: float = actor.global_position.distance_to(previous)
 previous = actor.global_position
 var moving: bool = actor.velocity.length()>15 and distance<100 and not actor.movement_locked and not Session.busy
 clock += delta*(12 if actor.velocity.length()>300 else 9)
 var breath := sin(clock*.26)*.012 if not moving else 0.0
 sprite.scale = sprite.scale.lerp(rest_scale*Vector2(1-breath*.5,1+breath),1-exp(-delta*12))
 sprite.rotation = lerp_angle(sprite.rotation,0.0,1-exp(-delta*14))
 sprite.offset = rest_offset
 shadow.scale.x = 3.2+(.1*sin(clock) if moving else 0)
 sample_clock -= delta
 if sample_clock<=0:
  sample_clock = .2
  water_nearby = sample_water()
  Ambience.water_proximity = 1.0 if water_nearby else 0.0
 if moving:
  step_distance += distance
  if step_distance>=33:
   step_distance = 0
   stamp(actor)
 else:step_distance = 0
 for i in range(prints.size()-1,-1,-1):
  var item: Dictionary = prints[i]
  item.age += delta
  item.sprite.modulate.a = .24*pow(maxf(0,1-item.age/2.4),1.5)
  if item.get("water",false):item.sprite.scale += Vector2(1,.5)*delta*.018
  if item.age>=2.4:
   item.sprite.queue_free()
   prints.remove_at(i)
func stamp(actor: Node2D) -> void:
 var world := actor.get_parent()
 var plan := preload("res://scripts/wonderland/layout.gd")
 if plan.regions().has(Session.area_id) and not plan.OUTDOORS.has(Session.area_id) and not water_nearby:return
 var ripple := water_nearby
 if ripple and world.get("map")!=null:
  var bridge := world.map.get_node_or_null("Bridges") as TileMapLayer
  if bridge!=null and bridge.get_cell_source_id(bridge.local_to_map(bridge.to_local(water_point)))>=0:ripple = false
 # Pawprints belong to terrain. No footprints on furniture, battle air or menus.
 var picture := Sprite2D.new()
 picture.texture = RIPPLE if ripple else PAW
 picture.material = ink_material
 picture.scale = Vector2(16,8)/512.0 if ripple else Vector2.ONE*(9.0/512.0)
 picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 picture.modulate = Color("#ddfbff") if ripple else Color("#62543e")
 picture.modulate.a = .24
 picture.z_index = -4
 world.add_child(picture)
 var facing: Vector2 = actor.facing_direction
 foot = 1-foot
 picture.global_position = water_point if ripple else actor.global_position+Vector2(0,24)+facing.orthogonal()*(5 if foot else -5)
 picture.rotation = 0 if ripple else facing.angle()+PI*.5
 prints.append({"sprite":picture,"age":0.0,"water":ripple})
