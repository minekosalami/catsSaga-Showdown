extends Node2D
## Shared cat presentation, including battles without CinematicArena (Incarna).
var sprite: Sprite2D
var rest := Vector2.ZERO
var shadow: Sprite2D
var clock := 0.0
func _ready() -> void:
 z_index = -1
 sprite = get_parent().get_node("Sprite2D")
 rest = sprite.offset
 shadow = Sprite2D.new()
 shadow.name = "GroundingShadow"
 shadow.texture = preload("res://assets/wonderland_human/ninja/Shadow.png")
 shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 shadow.scale = Vector2(3.5,1.2)
 shadow.position = sprite.position+Vector2(0,30)
 shadow.modulate.a = .4
 add_child(shadow)
func _process(delta: float) -> void:
 var player := get_parent()
 visible = player.health>0
 if not visible:return
 clock += delta
 # Existing cinematic animation remains the sole bob where it already exists.
 if player.has_node("CinematicPlayerVisual"):return
 var moving: bool = player.velocity.length()>20
 var bob := -absf(sin(clock*9))*1.1 if moving else 0.0
 sprite.offset = sprite.offset.lerp(rest+Vector2(0,bob/maxf(sprite.scale.y,.001)),1-exp(-delta*15))
