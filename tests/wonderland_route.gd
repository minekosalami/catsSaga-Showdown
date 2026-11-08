extends SceneTree
const Layout=preload("res://scripts/wonderland/layout.gd")
const Terrain=preload("res://scripts/wonderland/terrain.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 var links:=0
 for link in Layout.LINKS:
  if not Layout.OUTDOORS.has(link[0]):continue
  links+=1
  check(absi(Layout.ROUTE.find(link[0])-Layout.ROUTE.find(link[3]))==1,"No forward shortcut")
  var a:Vector2=Vector2(Layout.OUTDOORS[link[0]].offset)*16+Layout.edge(link[0],link[1],link[2],0)
  var b:Vector2=Vector2(Layout.OUTDOORS[link[3]].offset)*16+Layout.edge(link[3],link[4],link[5],0)
  check(a.is_equal_approx(b),"Physical seam alignment: "+link[0]+" / "+link[3])
  check(Layout.inward(link[1])==-Layout.inward(link[4]),"Opposite entry facings")
 check(links==Layout.ROUTE.size()-1,"Exactly one connected six-region chain")
 for id in Layout.ROUTE:
  var map=load("res://scenes/wonderland/"+id+".tscn").instantiate()
  var road=Terrain.occupied(map.get_node("GardenPaths"));var water=Terrain.occupied(map.get_node("FairytaleWater"))
  var overlap:=false
  for cell in road:
   if water.has(cell):overlap=true
  check(not overlap,"No stacked path/water terrain in "+id)
  var count:=0
  for portal in map.get_node("Portals").get_children():
   if not Layout.OUTDOORS.has(portal.destination):continue
   count+=1
   check(absi(Layout.ROUTE.find(portal.destination)-Layout.ROUTE.find(id))==1,"Baked scene has no obsolete shortcut")
   var found:=false
   for link in Layout.LINKS:
    if id not in [link[0],link[3]]:continue
    var a:=0 if id==link[0] else 3;var b:=3-a
    if link[b]!=portal.destination:continue
    found=true
    var entry=map.get_node("Entries/From_"+portal.destination)
    check(entry.position==Layout.edge(id,link[a+1],link[a+2],192),"Correct reverse spawn")
    for inset in [16,48,80,112,144,176,208]:
     var p=Layout.edge(id,link[a+1],link[a+2],inset)
     check(road.has(Vector2i(p/32)),"Continuous path to "+id+" seam")
   check(found,"Scene connection exists in geographic registry")
  check(count==(1 if id in [Layout.ROUTE[0],Layout.ROUTE[-1]] else 2),"Every required region is visited")
  map.free()
 var progress=load("res://scripts/maps/exploration.gd").new()
 progress.reveal("queens_castle",Vector2(1280,900))
 var saved=progress.snapshot();var restored=load("res://scripts/maps/exploration.gd").new()
 check(restored.restore(saved),"Existing per-region fog saves restore unchanged")
 var visibility:Image=restored.visibility_image("queens_castle")
 check(visibility.get_size()==Layout.extent("queens_castle"),"Fog atlas follows new geography")
 check(visibility.get_pixel(560,296).r>0,"Existing castle exploration moves with its region")
 print("WONDERLAND ROUTE: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
