extends SceneTree

const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)

func press(code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func type_code(code: String) -> void:
	for letter in code.to_upper(): await press(letter.unicode_at(0))

func cave_marker(ui: Node) -> Dictionary:
	for marker in ui.visible_boss_markers():
		if marker.id == "underground_cave": return marker
	return {}

func settle() -> void:
	while session.busy: await process_frame
	await physics_frame
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-map-debug.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path + suffix)
	await session.new_game()
	await settle()
	var world: Node = current_scene
	check(not session.unrestricted_region_access, "region override starts disabled")
	check(cave_marker(world.map_ui).is_empty(), "fresh save has no cave marker")
	await type_code("thefogisleaving")
	check(session.map_reveal_cheat and cave_marker(world.map_ui).is_empty(), "existing fog cheat works and cannot reveal undiscovered cave marker")
	await type_code("thefogisleaving")
	check(not session.map_reveal_cheat, "existing fog cheat toggles off")
	await press(KEY_M)
	check(world.map_ui.opened, "M still opens map immediately")
	await press(KEY_M)
	check(not world.map_ui.opened, "M still closes map immediately")
	await press(KEY_ESCAPE)
	await type_code("anywhereiwant")
	check(paused and not session.unrestricted_region_access, "debug codes do not activate through the pause menu")
	await press(KEY_ESCAPE)
	# Offset the parent to prove coordinates come from global_position, not position.
	world.position = Vector2(17,29)
	var point: Vector2 = world.player.global_position
	var local_point: Vector2 = world.player.position
	await type_code("mycoordinates")
	check(session.get_node("DebugNotification").text == "X: %s | Y: %s" % [str(point.x),str(point.y)], "coordinates show actual global X/Y with a translated parent")
	check(world.player.global_position == point and world.player.position == local_point, "coordinate code leaves player position unchanged")
	world.player.position += Vector2(32,16)
	point = world.player.global_position
	await type_code("mycoordinates")
	check(session.get_node("DebugNotification").text == "X: %s | Y: %s" % [str(point.x),str(point.y)] and world.player.global_position == point, "repeated coordinate code samples updated global position without moving player")
	world.position = Vector2.ZERO
	if world.map_ui.opened: await press(KEY_M)
	var movement_start: Vector2 = world.player.position
	var held := InputEventKey.new()
	held.keycode = KEY_A
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	await create_timer(.15).timeout
	held = InputEventKey.new()
	held.keycode = KEY_A
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	check(world.player.position.x < movement_start.x - 10, "standalone A still moves left despite region cheat prefix")
	await session.travel("deep_forest", "FromEntrance")
	await settle()
	world = current_scene
	var gate: Node = world.map.get_node("Characters/FloodedGate")
	var portal: Node = world.map.get_node("Portals/ToFlooded")
	var flags: Dictionary = session.story_flags.duplicate(true)
	check(not portal.can_travel() and gate.can_interact(), "key-gated region is normally locked")
	portal._on_body_entered(world.player)
	check(not session.busy and session.area_id == "deep_forest", "locked portal rejects travel")
	await type_code("anywhereiwant")
	check(session.unrestricted_region_access and session.get_node("DebugNotification").text.ends_with("enabled"), "region cheat enables with notification")
	check(portal.can_travel() and not gate.can_interact() and gate.get_node("Sign").text.contains("PATH OPEN"), "portal and gate signage honor override")
	check(session.story_flags == flags and not session.evil_bart_defeated, "override grants no items or story progress")
	check(not session.snapshot(session.area_id,world.player.position).has("unrestricted_region_access"), "override is absent from save data")
	portal._on_body_entered(world.player)
	check(session.busy, "unlocked portal starts existing transition")
	await settle()
	world = current_scene
	check(session.area_id == "flooded_forest" and session.story_flags == flags, "override enters locked forest without setting unlock flag")
	var shortcut: Node = world.map.get_node("Portals/ToBart")
	check(shortcut.can_travel(), "boss-defeat shortcut also honors centralized override")
	await type_code("anywhereiwant")
	check(not session.unrestricted_region_access and session.get_node("DebugNotification").text.ends_with("disabled"), "region cheat toggles off with notification")
	check(not shortcut.can_travel(), "boss-defeat restriction returns after disabling")
	await session.travel("deep_forest", "FromFlooded")
	await settle()
	world = current_scene
	check(not world.map.get_node("Portals/ToFlooded").can_travel() and world.map.get_node("Characters/FloodedGate").can_interact(), "key restriction and gate interaction return after disabling")
	# Existing legitimate progression still works with the override disabled.
	session.evil_bart_defeated = true
	session.story_flags["flooded_forest_key_obtained"] = true
	check(world.map.get_node("Portals/ToFlooded").can_travel(), "legitimate key and Bart progression still open normal route")
	await session.travel("flooded_forest", "FromDeep")
	await settle()
	world = current_scene
	var hole: Node2D = world.map.get_node("Characters/CaveHole")
	world.player.position = hole.position + Vector2(0,70)
	await process_frame
	await process_frame
	check(cave_marker(world.map_ui).is_empty(), "approaching cave opening alone does not discover marker")
	await press(KEY_Z)
	await settle()
	world = current_scene
	check(session.area_id == "underground_cave" and session.story_flags.get("underground_cave_discovered",false), "first successful descent records discovery")
	check(cave_marker(world.map_ui).is_empty(), "forest entrance marker is absent from separate underground map")
	check(session.saves.read_save().story_flags.get("underground_cave_discovered",false), "entry autosave persists cave discovery")
	world.player.position = world.map.get_node("Characters/ClimbToForest").position + Vector2(0,70)
	await process_frame
	await process_frame
	await press(KEY_Z)
	await settle()
	world = current_scene
	var marker := cave_marker(world.map_ui)
	check(not marker.is_empty() and marker.point == Layout.world_point("flooded_forest",hole_position()), "marker matches actual authored entrance coordinates")
	check(marker.get("label", "") == "Underground Cave", "marker has readable cave label")
	var fog: Dictionary = session.exploration.snapshot()
	world.map_ui._refresh()
	check(session.exploration.snapshot() == fog, "marker refresh does not reveal terrain in either map")
	session.story_flags.erase("underground_cave_discovered")
	check(await session.load_game(), "saved discovery can be loaded")
	await settle()
	check(not cave_marker(current_scene.map_ui).is_empty(), "cave marker remains visible after save/load")
	var legacy: Dictionary = session.saves.validate({"version":1,"area":"entrance","position":[280,450],"story_flags":{}})
	check(not legacy.is_empty() and not legacy.story_flags.get("underground_cave_discovered",false), "older saves remain valid and start with undiscovered cave")
	# The debug override remains a runtime property, not a saved progression flag.
	await type_code("anywhereiwant")
	check(session.unrestricted_region_access, "override can be enabled after returning from cave")
	check(await session.load_game() and session.unrestricted_region_access, "loading a save within same play session does not rewrite runtime override")
	await settle()
	await type_code("anywhereiwant")
	check(not session.unrestricted_region_access, "runtime override can still be disabled after loading")
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path + suffix)
	print("MAP DEBUG: %d checks, %d failures" % [checks,failures])
	# Let the headless audio thread retire MP3 playback before the test exits.
	for voice in root.get_node("Music").get_children():
		if voice is AudioStreamPlayer: voice.stop()
	await create_timer(.15).timeout
	quit(1 if failures else 0)

func hole_position() -> Vector2:
	return current_scene.map.get_node("Characters/CaveHole").position
