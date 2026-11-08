extends Sprite2D
## Authored eight-direction Neko frames, driven by travelled distance, never body wobble.
signal arrived
const SHEET=preload("res://assets/ambush_human/oneko.png")
const DIRECTIONS=[ [Vector2i(3,0),Vector2i(3,1)], [Vector2i(5,1),Vector2i(5,2)], [Vector2i(6,3),Vector2i(7,2)], [Vector2i(5,3),Vector2i(6,1)], [Vector2i(4,2),Vector2i(4,3)], [Vector2i(1,0),Vector2i(1,1)], [Vector2i(1,2),Vector2i(1,3)], [Vector2i(0,2),Vector2i(0,3)] ]
var route:=PackedVector2Array()
var route_index:=0
var pace:=120.0
var speed:=0.0
var stride:=0.0
var heading:=0.0
var look:=Vector2.RIGHT
var delay:=0.0
var walking:=false
var distance_walked:=0.0
var peers:Array=[]
var nav:RefCounted
var waiting:=0.0
var ordinal:=0
func _ready() -> void:
 texture=SHEET;region_enabled=true;region_rect=Rect2(96,96,32,32)
 scale=Vector2.ONE*2;offset=Vector2(0,-13);texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var contact:=Sprite2D.new();contact.name="GroundContact"
 contact.texture=preload("res://assets/wonderland_human/ninja/Shadow.png")
 contact.scale=Vector2(1.1,.5);contact.modulate.a=.35;contact.show_behind_parent=true
 add_child(contact)
func face(point:Vector2) -> void:look=(point-global_position).normalized()
func walk(points:PackedVector2Array,velocity:=120.0,start_delay:=0.0) -> void:
 route=points;route_index=1 if points.size()>1 else 0;pace=velocity;delay=start_delay;walking=not points.is_empty();speed=0;waiting=0
 if points.size()>1:look=(points[1]-position).normalized()
func _physics_process(delta:float) -> void:
 if delay>0:delay-=delta;return
 if walking:
  var target:Vector2=route[route_index];var delta_position:=target-position
  if delta_position.length()<2:
   position=target;route_index+=1
   if route_index>=route.size():walking=false;speed=0;arrived.emit();return
   target=route[route_index];delta_position=target-position
  look=delta_position.normalized()
  var end_distance:float=position.distance_to(route[-1])
  speed=move_toward(speed,minf(pace,sqrt(maxf(0,end_distance)*520)),500*delta)
  var motion:=look*minf(speed*delta,delta_position.length())
  var blocked:=false
  for other in peers:
   if other==self or not is_instance_valid(other) or not other.visible:continue
   if (position+motion).distance_to(other.position)<44 and position.distance_to(other.position)>(position+motion).distance_to(other.position):blocked=true;break
  if blocked:
   waiting+=delta;speed=0
   if waiting>.6 and nav!=null:
    var obstacles:Array[Vector2]=[]
    for other in peers:
     if other!=self and is_instance_valid(other) and other.visible:obstacles.append(other.position)
    var alternative:PackedVector2Array=nav.path(position,route[-1],obstacles)
    if alternative.size()>1:route=alternative;route_index=1
    waiting=0
  else:
   waiting=0;position+=motion;stride+=motion.length();distance_walked+=motion.length()
 # A turn walks through adjacent authored facings; the sprite is never rotated on its feet.
 if look.length_squared()>.1:heading=rotate_toward(heading,look.angle(),delta*6)
 var direction:=posmod(roundi(heading/(PI/4)),8)
 var frame:int=int(stride/14)%2 if walking and speed>0 else 1
 var cell:Vector2i=DIRECTIONS[direction][frame]
 region_rect=Rect2(Vector2(cell*32),Vector2(32,32))

func _exit_tree() -> void:
 peers=[];nav=null;route.clear()
