extends RefCounted
## One terrain occupancy mask per material, with artist-authored convex/concave quarters.
static func occupied(layer:TileMapLayer) -> Dictionary:
 var result:Dictionary={}
 for p in layer.get_used_cells():result[Vector2i(floori(p.x/2.0),floori(p.y/2.0))]=true
 return result
static func repaint(layer:TileMapLayer,mask:Dictionary,water:=false) -> void:
 layer.clear()
 layer.tile_set=layer.tile_set.duplicate(true)
 var source=layer.tile_set.get_source(0) as TileSetAtlasSource
 var top:=6 if water else 7
 for p:Vector2i in mask:
  for y in 2:
   for x in 2:
    var h:=Vector2i(-1 if x==0 else 1,0);var v:=Vector2i(0,-1 if y==0 else 1)
    var has_h:bool=mask.has(p+h);var has_v:bool=mask.has(p+v)
    var uv:=Vector2i(12,top+1)
    if not has_h:uv.x=11 if x==0 else 13
    if not has_v:uv.y=top if y==0 else top+2
    if has_h and has_v and not mask.has(p+h+v):
     uv=Vector2i(18 if x==0 else 19,top+2) if y==0 else Vector2i(17 if x==0 else 20,top+1)
    uv=uv*2+Vector2i(x,y)
    if not source.has_tile(uv):
     source.create_tile(uv)
     if water:
      var data=source.get_tile_data(uv,0);var half=layer.tile_set.tile_size.x*.5
      data.set_collision_polygons_count(0,1)
      data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-half,-half),Vector2(half,-half),Vector2(half,half),Vector2(-half,half)]))
    layer.set_cell(p*2+Vector2i(x,y),0,uv)
static func paint_route(mask:Dictionary,points:PackedVector2Array,width:float,size:Vector2) -> void:
 for i in range(1,points.size()):
  var a=points[i-1];var b=points[i]
  var lo:=Vector2i((a.min(b)-Vector2.ONE*width)/32).max(Vector2i.ZERO)
  var hi:=Vector2i((a.max(b)+Vector2.ONE*width)/32).min(Vector2i(size/32)-Vector2i.ONE)
  for y in range(lo.y,hi.y+1):
   for x in range(lo.x,hi.x+1):
    var p:=Vector2(x*32+16,y*32+16)
    if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<width:mask[Vector2i(x,y)]=true
