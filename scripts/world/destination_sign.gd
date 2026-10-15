extends Node2D
## A physical human-drawn sign, using the existing Z interaction/dialogue system.
@export var destination_text := ""
@export var interaction_radius := 110.0
var route: Node
func _ready() -> void:
 add_to_group("interactables")
 add_to_group("destination_signs")
 set_meta("interaction_label","Z  Read sign")
 var art := Sprite2D.new()
 var atlas := AtlasTexture.new()
 atlas.atlas = preload("res://assets/wonderland_human/rpg/roguelikeSheet_transparent.png")
 atlas.region = Rect2(19*17,0,16,16)
 art.texture = atlas
 art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 art.scale = Vector2.ONE*3
 art.position.y = -22
 if Session.area_id == "underground_cave": art.modulate = Color("#c1c6d2")
 elif preload("res://scripts/wonderland/layout.gd").regions().has(Session.area_id): art.modulate = Color("#fff1eb")
 add_child(art)
func can_interact() -> bool: return true
func read_text() -> String:
 var text := destination_text
 if is_instance_valid(route) and route.has_method("can_travel"):
  text += "\nRoute open." if route.can_travel() else "\nRoute locked."
 return text
func handle_interaction(world: Node) -> bool:
 world.conversation_flag = ""
 world.pending_battle = false
 world.dialogue.start_lines([{"speaker":"SIGNPOST","text":read_text()}])
 world.hide_interaction()
 world.player.movement_locked = true
 return true
static func install(map: Node2D) -> void:
 var names := {"entrance":"Forest Entrance","deep_forest":"Deep Forest","bart_area":"Evil Bart's Area","flooded_forest":"Flooded Forest","underground_cave":"Underground Cave"}
 for id in preload("res://scripts/wonderland/layout.gd").regions(): names[id] = preload("res://scripts/wonderland/layout.gd").regions()[id].name
 var sources: Array[Node] = []
 for portal in map.get_node("Portals").get_children():
  if portal.get("destination") != null:sources.append(portal)
 for label in map.find_children("*","Label",true,false):
  var text := String(label.text).strip_edges()
  var is_destination := label.get_parent().get_parent() == map.get_node("Portals") or label.name == "Sign"
  for destination in names.values():
   if text == destination: is_destination = true
  if is_destination: label.hide()
 for source in sources:
  if map.has_node("Sign_"+str(source.name)):continue
  var sign = load("res://scripts/world/destination_sign.gd").new()
  sign.name = "Sign_"+str(source.name)
  sign.destination_text = names.get(source.destination,source.destination.replace("_"," ").capitalize())
  sign.route = source
  var point: Vector2 = map.to_local(source.global_position)
  var size: Vector2 = map.map_size
  # A little inside the edge, beside the path rather than over the transition.
  var horizontal_edge := point.y < 100 or point.y > size.y-100
  var offset := Vector2(92,80 if point.y < size.y*.5 else -80) if horizontal_edge else Vector2(80 if point.x < size.x*.5 else -80,80)
  if point.x > 160 and point.x < size.x-160 and point.y > 160 and point.y < size.y-160:offset = Vector2(100,-35 if point.y > size.y*.75 else 55)
  sign.position = (point+offset).clamp(Vector2(64,72),size-Vector2(64,64))
  var plan := preload("res://scripts/wonderland/layout.gd")
  if plan.regions().has(Session.area_id) and not plan.OUTDOORS.has(Session.area_id):
   if point.x < 100:sign.position = Vector2(224,point.y+64)
   elif point.x > size.x-100:sign.position = Vector2(size.x-224,point.y+64)
   elif point.y < 100:sign.position = Vector2(point.x+100,300)
  map.add_child(sign)
