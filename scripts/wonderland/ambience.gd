extends Node2D
## Animate human atlas art with transforms only; no generated particle artwork.
@export var indoor := false
var clock := 0.0
var ornaments: Array[Node2D] = []
var accumulator := 0.0
func _ready() -> void:
 for node in get_tree().get_nodes_in_group("wonderland_ornaments"):
  if get_parent().is_ancestor_of(node) and node.kind in ["flowers","roses","giant_flower","fountain","teapot","mushroom"]:ornaments.append(node)
func _process(delta: float) -> void:
 clock += delta
 accumulator += delta
 if accumulator < .083:return
 accumulator = 0
 for node in ornaments:
  if not get_viewport_rect().grow(300).has_point(get_canvas_transform()*node.global_position):continue
  if node.kind in ["flowers","roses","giant_flower"]:node.rotation = sin(clock*.8+node.position.x*.01)*.018
  if node.kind == "fountain":node.modulate = Color.WHITE.lerp(Color("#d4f6ff"),.25+.12*sin(clock*2))
  node.tick(clock)
