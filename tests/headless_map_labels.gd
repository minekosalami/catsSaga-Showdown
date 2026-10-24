extends SceneTree
## Exercises actual WORLD_MAP labels and their matching tooltip hit rectangles.
var checks:=0
var failures:=0

func _initialize() -> void:
	create_timer(60).timeout.connect(func():push_error("Map-label validation timed out");quit(1))
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	if ok:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)

func verify(canvas: Control,name: String) -> void:
	var ink:=canvas.get_node("Ink")
	var before: Array=canvas.boss_markers.duplicate(true)
	var labels: Array=ink.label_layout()
	var intersections:=0
	var outside:=0
	var incorrect_tooltips:=0
	for i in labels.size():
		var label: Dictionary=labels[i]
		var rect: Rect2=label.rect
		if not label.region and not Rect2(Vector2.ZERO,canvas.size).encloses(rect):outside+=1
		for j in range(i+1,labels.size()):
			if rect.intersects(labels[j].rect):intersections+=1;print("OVERLAP ",label.marker.id," / ",labels[j].marker.id)
		var marker: Dictionary=label.marker
		var expected: String=ink.marker_name(marker)+"\n"+preload("res://scripts/maps/world_layout.gd").region(marker.area).name+"\nX: "+str(marker.local_position.x)+" | Y: "+str(marker.local_position.y)
		if ink._get_tooltip(rect.get_center())!=expected:incorrect_tooltips+=1
	check(labels.size()>5,name+": real regions, boss and save labels are present")
	check(intersections==0,name+": all rendered labels have nonintersecting rectangles")
	check(outside==0,name+": point labels remain within the viewport")
	check(incorrect_tooltips==0,name+": every moved label has the correct tooltip at its rendered rectangle")
	check(canvas.boss_markers==before,name+": label layout preserves original marker coordinates and discovery data")
	check(ink.label_layout()==labels,name+": repeated layout is deterministic")

func run() -> void:
	root.size=Vector2i(1280,720)
	var session:=root.get_node("Session")
	await session.new_game()
	await process_frame
	session.reveal_all_locations=true
	var ui: Node=current_scene.map_ui
	ui.open_map()
	await process_frame
	ui._refresh()
	check(ui.opened and ui.full_map.size.x>1000,"real WORLD_MAP opens at the project design resolution")
	verify(ui.full_map,"default zoom with undiscovered debug markers")
	var saves: Dictionary=load("res://scripts/world/save_statue.gd").get_script_constant_map().LOCATIONS
	for area: String in saves:
		for point: Vector2 in saves[area]:session.exploration.reveal(area,point)
	for boss: Dictionary in ui.boss_locations.values():session.exploration.reveal(boss.area,boss.local_position)
	session.reveal_all_locations=false
	ui._refresh()
	check(ui.full_map.boss_markers.size()==7,"all three bosses and four discovered saves use the existing marker collection")
	verify(ui.full_map,"default zoom with all markers discovered")
	ui.full_map.zoom=.8
	verify(ui.full_map,"zoomed out")
	ui.full_map.zoom=1.8
	ui.full_map.center_world=Vector2(440,60)
	verify(ui.full_map,"zoomed and panned")
	check(ui.minimap.get_node("Ink").label_layout().is_empty() and ui.minimap.get_node("Ink")._get_tooltip(Vector2(75,75)).is_empty(),"circular minimap retains its existing dot-only presentation")
	ui.close_modals()
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("MAP LABELS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
