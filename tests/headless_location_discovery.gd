extends SceneTree
const Layout = preload("res://scripts/maps/world_layout.gd")
var session: Node
var checks := 0
var failures := 0
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func settle() -> void:
	while session.busy: await process_frame
	await physics_frame
	await process_frame
	await process_frame
func marker(ui: Node, id: String) -> Dictionary:
	for value in ui.visible_boss_markers():
		if value.id == id: return value
	return {}
func regions(ui: Node) -> Array:
	return ui.visible_region_markers().map(func(value): return value.id)
func click(button: Button) -> void:
	await process_frame
	await process_frame
	session.developer_menu.scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-location-discovery.json"
	await session.new_game()
	await settle()
	var world: Node = current_scene
	var ui: Node = world.map_ui
	check(regions(ui) == ["entrance"],"new game shows only entered region name")
	check(ui.visible_boss_markers().is_empty(),"undiscovered boss and cave markers are hidden")
	session.developer_cheats.activate("thefogisleaving")
	check(regions(ui) == ["entrance"] and ui.visible_boss_markers().is_empty(),"terrain reveal cannot discover or expose unknown location markers")
	session.developer_cheats.activate("thefogisleaving")
	var flags: Dictionary = session.story_flags.duplicate(true)
	var fog: Dictionary = session.exploration.snapshot()
	session.developer_menu.show_menu()
	await click(session.developer_menu.controls.reveal_locations)
	check(session.reveal_all_locations and session.developer_menu.controls.reveal_locations.button_pressed,"new menu toggle reflects location reveal state")
	session.developer_menu.close_menu()
	await process_frame
	check(regions(ui).size() == 4,"debug reveal shows all forest region labels")
	check(ui.visible_boss_markers().size() == 3,"debug reveal shows two known bosses and cave entrance")
	for value in ui.visible_boss_markers():
		check(not value.discovered and value.color == Color("#E4B765"),value.id+" debug marker is distinguished as undiscovered")
	check(session.story_flags == flags and session.exploration.snapshot() == fog,"marker visualization changes neither story progress nor fog")
	var cave := marker(ui,"underground_cave")
	check(cave.local_position == ui.cave_entrance and cave.local_position == Vector2(1696,1008),"cave locator uses the real Flooded Forest scene position")
	ui.open_map()
	ui.full_map.center_world = cave.point
	ui._refresh()
	await process_frame
	await process_frame
	var tip: String = ui.full_map.get_node("Ink")._get_tooltip(ui.full_map.screen_point(cave.point))
	check(tip.contains("Underground Cave [?]") and tip.contains("Flooded Forest") and tip.contains("X: 1696.0 | Y: 1008.0"),"cave tooltip exposes name, correct region, coordinates and debug discovery state")
	ui.close_modals()
	session.developer_cheats.activate("reveal_locations")
	ui._refresh()
	check(regions(ui) == ["entrance"] and ui.visible_boss_markers().is_empty(),"turning off reveal immediately restores normal filtering")
	session.developer_menu.show_menu()
	await click(session.developer_menu.controls.mycoordinates)
	session.developer_menu.close_menu()
	await process_frame
	await process_frame
	check(session.show_coordinates and session.coordinate_overlay.visible,"Show Coordinates survives developer menu close")
	var origin: Vector2 = world.player.position
	world.player.position += Vector2(48,32)
	await process_frame
	await process_frame
	var point: Vector2 = world.player.global_position
	check(session.coordinate_overlay.text == "X: %.1f | Y: %.1f" % [point.x,point.y],"overlay updates live from player global_position")
	for down in [true,false]:
		var move := InputEventKey.new()
		move.keycode = KEY_D
		move.pressed = down
		Input.parse_input_event(move)
		Input.flush_buffered_events()
		if down: await create_timer(.15).timeout
	await process_frame
	await process_frame
	var moved: Vector2 = world.player.global_position
	check(moved.x > point.x+10 and session.coordinate_overlay.text == "X: %.1f | Y: %.1f" % [moved.x,moved.y],"real movement updates persistent coordinates after menu close")
	check(session.coordinate_overlay.get_global_rect().end.x <= root.get_visible_rect().end.x and session.coordinate_overlay.get_global_rect().end.y <= root.get_visible_rect().end.y,"overlay is within bottom-right viewport bounds")
	world.player.position = origin
	await session.travel("deep_forest","FromEntrance")
	await settle()
	ui = current_scene.map_ui
	check("deep_forest" in regions(ui) and "entrance" in regions(ui),"first region entry discovers its label and retains prior region")
	check(session.show_coordinates and session.coordinate_overlay.visible,"live overlay remains enabled after region travel")
	var saved: Dictionary = session.saves.read_save()
	check(not saved.has("show_coordinates") and not saved.has("reveal_all_locations"),"debug visualization flags are absent from saves")
	check(await session.load_game(),"region discovery save loads")
	await settle()
	check("entrance" in regions(current_scene.map_ui) and "deep_forest" in regions(current_scene.map_ui),"entered regions remain discovered after load")
	session.developer_cheats.activate("reveal_locations")
	check(await session.load_game(),"loading works with both debug overlays enabled")
	await settle()
	check(session.show_coordinates and session.reveal_all_locations,"both new visualization toggles survive loading within current session")
	session.developer_cheats.activate("reveal_locations")
	# Boss proximity is already recorded in the saved exploration bitset.
	session.exploration.reveal("bart_area",Vector2(1000,450))
	current_scene.map_ui._refresh()
	check(not marker(current_scene.map_ui,"bart").is_empty() and marker(current_scene.map_ui,"boss2").is_empty(),"proximity discovers only the explored boss marker")
	check(session.save_current(),"proximity discovery saves using existing fog data")
	check(await session.load_game(),"boss proximity save loads")
	await settle()
	check(not marker(current_scene.map_ui,"bart").is_empty(),"boss marker discovery remains after save/load")
	# Actual first descent must discover the entrance; standing beside it is insufficient.
	await session.travel("flooded_forest","FromDeep")
	await settle()
	world = current_scene
	ui = world.map_ui
	check(marker(ui,"underground_cave").is_empty(),"entering Flooded Forest does not discover cave entrance")
	var hole: Node2D = world.map.get_node("Characters/CaveHole")
	world.player.position = hole.position+Vector2(0,70)
	await process_frame
	await process_frame
	check(marker(ui,"underground_cave").is_empty(),"approaching cave still leaves marker hidden")
	hole.handle_interaction(world)
	await settle()
	check(session.area_id == "underground_cave" and session.story_flags.get("underground_cave_discovered",false),"real descent records cave discovery")
	check(session.coordinate_overlay.visible and session.show_coordinates,"live coordinates work underground without a second overlay")
	session.developer_cheats.activate("reveal_locations")
	check(regions(current_scene.map_ui) == ["underground_cave"] and current_scene.map_ui.visible_boss_markers().is_empty(),"cave debug map never mixes in forest markers")
	current_scene.player.position = current_scene.map.get_node("Characters/ClimbToForest").position+Vector2(0,70)
	await process_frame
	await process_frame
	current_scene.map.get_node("Characters/ClimbToForest").handle_interaction(current_scene)
	await settle()
	ui = current_scene.map_ui
	check(marker(ui,"underground_cave").discovered,"returning shows cave as legitimately discovered")
	session.developer_cheats.activate("reveal_locations")
	check(not marker(ui,"underground_cave").is_empty(),"turning debug off preserves true cave discovery")
	check(await session.load_game(),"cave discovery save loads")
	await settle()
	check(marker(current_scene.map_ui,"underground_cave").discovered,"cave marker persists after loading")
	var legacy: Dictionary = session.saves.validate({"version":1,"area":"underground_cave","position":[1936,1904],"exploration":session.exploration.snapshot(),"story_flags":{"legacy_flag":true}})
	check(not legacy.is_empty() and legacy.story_flags.legacy_flag,"older save remains compatible without new fields")
	var kept_flags: Dictionary = session.story_flags.duplicate()
	session.story_flags = legacy.story_flags.duplicate()
	check(marker(current_scene.map_ui,"underground_cave").discovered,"old saved cave exploration preserves discovery without newer cave flag")
	session.story_flags = kept_flags
	session.developer_cheats.activate("mycoordinates")
	await process_frame
	await process_frame
	check(not session.coordinate_overlay.visible and not session.show_coordinates,"disabling coordinates completely hides overlay")
	for voice in root.get_node("Music").get_children():
		if voice is AudioStreamPlayer: voice.stop()
	await create_timer(.15).timeout
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("LOCATION DISCOVERY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
