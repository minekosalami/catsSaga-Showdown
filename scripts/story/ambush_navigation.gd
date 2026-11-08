extends RefCounted
var map:Node2D
var grid:=AStarGrid2D.new()
var query:=PhysicsShapeQueryParameters2D.new()
var origin:=Vector2.ZERO
var step:=20.0
func setup(world:Node,center:Vector2) -> void:
 map=world.map;origin=(center-Vector2(720,540)).snapped(Vector2.ONE*step).max(Vector2.ZERO)
 var end:Vector2=(center+Vector2(720,540)).min(map.map_size-Vector2.ONE*20)
 grid.region=Rect2i(Vector2i.ZERO,Vector2i((end-origin)/step)+Vector2i.ONE);grid.cell_size=Vector2.ONE*step;grid.offset=origin
 grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 var shape:=CircleShape2D.new();shape.radius=23;query.shape=shape;query.collision_mask=1;query.exclude=[world.player.get_rid()]
 for y in grid.region.size.y:
  for x in grid.region.size.x:
   var p:=origin+Vector2(x,y)*step
   if not clear(p):grid.set_point_solid(Vector2i(x,y),true)
func clear(p:Vector2) -> bool:
 if not Rect2(Vector2.ONE*24,map.map_size-Vector2.ONE*48).has_point(p) or not map.is_walkable_position(p):return false
 query.transform=Transform2D(0,p)
 return map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func nearest(p:Vector2) -> Vector2:
 var best:=p;var distance:=INF
 for y in grid.region.size.y:
  for x in grid.region.size.x:
   var cell:=Vector2i(x,y)
   if grid.is_point_solid(cell):continue
   var q:Vector2=grid.get_point_position(cell);var d:=q.distance_squared_to(p)
   if d<distance:best=q;distance=d
 return best
func visible(a:Vector2,b:Vector2,obstacles:Array[Vector2]) -> bool:
 for i in range(ceili(a.distance_to(b)/8)+1):
  var p:=a.lerp(b,float(i)/maxf(1,ceili(a.distance_to(b)/8)))
  if not clear(p):return false
  for other in obstacles:
   if p.distance_to(other)<48:return false
 return true
func path(a:Vector2,b:Vector2,obstacles:Array[Vector2]=[]) -> PackedVector2Array:
 var changed:Array[Vector2i]=[]
 for point in obstacles:
  var c:=Vector2i((point-origin)/step)
  for dy in range(-3,4):
   for dx in range(-3,4):
    var cell:=c+Vector2i(dx,dy)
    if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and grid.get_point_position(cell).distance_to(point)<48:
     grid.set_point_solid(cell,true);changed.append(cell)
 var start:=Vector2i(((a-origin)/step).round());var goal:=Vector2i(((b-origin)/step).round())
 var raw:=PackedVector2Array()
 if grid.is_in_boundsv(start) and grid.is_in_boundsv(goal) and not grid.is_point_solid(start) and not grid.is_point_solid(goal):raw=grid.get_point_path(start,goal)
 for cell in changed:grid.set_point_solid(cell,false)
 if raw.is_empty():return raw
 raw[0]=a;raw[-1]=b
 # Visibility-checked corner cutting: smooth enough to walk, never through terrain.
 var result:=PackedVector2Array([a]);var index:=0
 while index<raw.size()-1:
  var next:=index+1
  for j in range(index+2,raw.size()):
   if visible(raw[index],raw[j],obstacles):next=j
   else:break
  result.append(raw[next]);index=next
 # Round corners with sampled quadratic arcs only when the full swept route is clear.
 var curved:=PackedVector2Array([result[0]])
 for i in range(1,result.size()-1):
  var corner:=result[i]
  var enter:Vector2=corner.move_toward(result[i-1],minf(48,corner.distance_to(result[i-1])*.3))
  var leave:Vector2=corner.move_toward(result[i+1],minf(48,corner.distance_to(result[i+1])*.3))
  var arc:=PackedVector2Array([enter]);var valid:=true
  for j in range(1,9):
   var t:=j/8.0;var p:Vector2=enter.lerp(corner,t).lerp(corner.lerp(leave,t),t)
   if not visible(arc[-1],p,obstacles):valid=false;break
   arc.append(p)
  if valid:curved.append_array(arc)
  else:curved.append(corner)
 curved.append(result[-1])
 return curved
func ring(center:Vector2) -> Array[Vector2]:
 var result:Array[Vector2]=[]
 for i in 8:
  var best:=Vector2.INF;var score:=INF
  for radius in [190,210,170,230,250,150,270,290]:
   for turn in [0,-.12,.12,-.24,.24]:
    var angle:float=i*TAU/8+PI/8+turn
    var p:Vector2=(center+Vector2.from_angle(angle)*radius-origin).snapped(Vector2.ONE*step)+origin
    if not clear(p):continue
    var close:=false
    for other in result:
     if other.distance_to(p)<70:close=true
    if close or path(center,p).is_empty():continue
    var value:float=absf(radius-205)+absf(turn)*180
    if value<score:score=value;best=p
  if best==Vector2.INF:
   # A narrow bank may require a wider, still connected arc.
   for y in grid.region.size.y:
    for x in grid.region.size.x:
     var cell:=Vector2i(x,y)
     if grid.is_point_solid(cell):continue
     var p:Vector2=grid.get_point_position(cell)
     var occupied:=false
     for other in result:
      if p.distance_to(other)<70:occupied=true;break
     if occupied or p.distance_to(center)<140:continue
     var value:float=p.distance_to(center+Vector2.from_angle(i*TAU/8+PI/8)*235)
     if value>=score or path(center,p).is_empty():continue
     score=value;best=p
   if best==Vector2.INF:push_error("No connected ambush formation space");return []
  result.append(best)
 return result
