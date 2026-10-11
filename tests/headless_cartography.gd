extends SceneTree

const Layout = preload("res://scripts/maps/world_layout.gd")
const Exploration = preload("res://scripts/maps/exploration.gd")
var checks := 0
var failures := 0
var session: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func press(code: int) -> void:
	key(code,true)
	await process_frame
	await physics_frame
	key(code,false)
	await process_frame

func type_code() -> void:
	for letter in "THEFOGISLEAVING": await press(letter.unicode_at(0))

func wheel(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-cartography.json"
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	var fresh := Exploration.new()
	for area in Layout.REGIONS:
		check(not fresh.visited(area,Vector2i.ZERO),area+" starts unexplored")
	var first := fresh.reveal("entrance",Vector2(280,450))
	check(not first.is_empty(),"normal exploration reveals nearby cells")
	check(fresh.reveal("entrance",Vector2(280,450)).is_empty(),"standing still does not keep uploading fog")
	check(not fresh.visited("deep_forest",Vector2i(4,7)),"revealing one region does not reveal another")
	var copy := Exploration.new()
	check(copy.restore(fresh.snapshot()) and copy.snapshot() == fresh.snapshot(),"bitset exploration round-trips exactly")
	check(not copy.restore({"wrong_region":"AAAA"}),"unknown exploration region rejected")
	check(not copy.restore({"entrance":"?"}),"corrupt exploration encoding rejected")
	var legacy: Dictionary = session.saves.validate({"version":1,"area":"entrance","position":[280,450],"story_flags":{"unrelated_flag":true}})
	check(not legacy.is_empty() and legacy.story_flags.unrelated_flag and legacy.exploration == Exploration.new().snapshot(),"old V1 saves gain empty fog without losing flags")
	check(session.saves.validate({"version":1,"area":"entrance","position":[280,450],"exploration":{"entrance":"bad"}}).is_empty(),"malformed saved fog rejected safely")
	var encoded_size := 0
	for area in Layout.REGIONS: encoded_size += fresh.snapshot()[area].length()
	check(encoded_size <= 1700,"four-region fog bitsets occupy under 1700 base64 characters")
	check(Layout.world_point("entrance",Vector2(160,320)) == Vector2(10,20),"Entrance uses uniform 16px-to-map transform")
	check(Layout.world_point("deep_forest",Vector2(160,320)) == Vector2(210,20),"Deep Forest occupies northeast")
	check(Layout.world_point("bart_area",Vector2(160,320)) == Vector2(10,134),"Bart occupies southwest")
	check(Layout.world_point("flooded_forest",Vector2(160,320)) == Vector2(210,200),"Flooded Forest occupies southeast")
	await session.new_game()
	await process_frame
	await process_frame
	var world: Node = current_scene
	var ui: Node = world.map_ui
	check(ui.minimap.visible and ui.minimap.size == Vector2(150,150) and ui.minimap.position == Vector2(24,24),"150px minimap appears top-left")
	check(ui.minimap.circular and ui.minimap.shader.get_shader_parameter("circular"),"minimap uses circular clipping")
	check(not ui.full_map.circular,"world map remains rectangular")
	check(ui.minimap.shader.get_shader_parameter("terrain") == ui.full_map.shader.get_shader_parameter("terrain"),"both maps share one cached terrain texture")
	check(ui.minimap.shader.get_shader_parameter("explored") == ui.full_map.shader.get_shader_parameter("explored"),"both maps share one fog texture")
	check(ui.minimap.shader.get_shader_parameter("terrain").get_size() == Vector2(Layout.SIZE),"map cache is only 520x372, not full-resolution scenes")
	check(not world.map.material is ShaderMaterial,"fog shader does not attach to the gameplay world")
	check(world.player.sprite.texture.resource_path == "res://assets/player/player.png.png","player artwork remains unchanged")
	var original_position: Vector2 = world.player.position
	await press(KEY_M)
	check(ui.opened and not ui.inventory_opened and not ui.minimap.visible,"M opens world map without inventory or duplicate minimap")
	check(not world.map.visible and not world.player.visible,"opaque map avoids drawing covered gameplay sprites")
	check(ui.full_map.center_world == Layout.world_point(session.area_id,original_position),"map initially centers exactly on the player")
	check(world.player.movement_locked and session.world_menu_open(),"map participates in existing modal movement lock")
	var old_center: Vector2 = ui.full_map.center_world
	key(KEY_RIGHT,true)
	await create_timer(0.18).timeout
	key(KEY_RIGHT,false)
	check(ui.full_map.center_world.x > old_center.x,"arrow key pans map east")
	check(world.player.position == original_position and world.player.velocity == Vector2.ZERO,"map panning does not move actual character")
	check(ui.full_map.player_world == Layout.world_point(session.area_id,original_position),"player marker stays in correct world coordinates while panning")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(ui.target_zoom > 2.0,"wheel up zooms in")
	for i in 35: await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(ui.target_zoom == 12.0,"map zoom maximum enforced")
	for i in 60: await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(ui.target_zoom == 0.8,"map zoom minimum enforced")
	key(KEY_RIGHT,true)
	ui._process(100.0)
	key(KEY_RIGHT,false)
	check(ui.full_map.center_world.x <= Layout.SIZE.x,"panning is bounded at east edge")
	await press(KEY_SPACE)
	check(ui.opened and not ui.inventory_opened,"Space cannot stack inventory over map")
	await press(KEY_ESCAPE)
	check(not ui.opened and not paused and not session.pause_menu.opened,"Escape closes map without opening pause")
	check(world.map.visible and world.player.visible,"closing map immediately restores gameplay visuals")
	await press(KEY_M)
	await press(KEY_M)
	check(not ui.opened and ui.minimap.visible,"M closes map and restores minimap")
	await press(KEY_SPACE)
	check(ui.inventory_opened and ui.inventory_contents.text == "No items collected.","Space opens empty actual inventory")
	await press(KEY_M)
	check(ui.inventory_opened and not ui.opened,"M cannot stack map over inventory")
	await press(KEY_SPACE)
	check(not ui.inventory_opened,"Space closes inventory")
	key(KEY_RIGHT,true)
	await create_timer(0.16).timeout
	key(KEY_RIGHT,false)
	await create_timer(0.2).timeout
	check(world.player.position.x > original_position.x+15 and world.player.facing_direction == Vector2.RIGHT,"normal arrows still move player and record facing")
	check(ui.minimap.center_world == Layout.world_point(session.area_id,world.player.position),"minimap follows player world position")
	check(ui.minimap.facing == Vector2.RIGHT,"minimap arrow follows facing direction")
	await create_timer(0.15).timeout
	check(world.player.facing_direction == Vector2.RIGHT,"standing still retains last facing")
	var exploration_before: Dictionary = session.exploration.snapshot()
	var flags_before: Dictionary = session.story_flags.duplicate()
	var normal_modulate: Color = world.map.modulate
	var terrain_before := hash(ui.fog_image.get_data())
	var cheat_position: Vector2 = world.player.position
	await type_code()
	check(session.map_reveal_cheat and ui.minimap.shader.get_shader_parameter("reveal_all"),"uppercase keyboard code reveals minimap")
	check(session.exploration.snapshot() == exploration_before,"cheat does not mark unexplored cells as visited")
	check(hash(ui.fog_image.get_data()) == terrain_before,"cheat leaves legitimate fog texture unchanged")
	check(world.player.position == cheat_position,"typing cheat does not produce accidental movement")
	check(session.story_flags == flags_before and not session.evil_bart_defeated,"cheat does not change progression, items or bosses")
	check(world.map.modulate == normal_modulate,"map reveal does not change gameplay lighting")
	await press(KEY_M)
	check(ui.full_map.shader.get_shader_parameter("reveal_all"),"full map uses same reveal state")
	exploration_before = session.exploration.snapshot()
	await type_code()
	check(session.map_reveal_cheat,"code is ignored while world map is open")
	await press(KEY_M)
	await type_code()
	check(not session.map_reveal_cheat and not ui.minimap.shader.get_shader_parameter("reveal_all"),"typing code again restores normal fog")
	check(session.exploration.snapshot() == exploration_before,"legitimate exploration remains after cheat toggles off")
	await press(KEY_T)
	check(ui.sequence == "t","partial code starts hidden prefix buffer")
	await create_timer(1.7).timeout
	check(ui.sequence.is_empty() and not world.player.movement_locked,"incomplete sequence times out and releases movement")
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await process_frame
	await type_code()
	check(not session.map_reveal_cheat and ui.sequence.is_empty(),"typing into a text field cannot trigger cheat")
	field.release_focus()
	field.free()
	await press(KEY_ESCAPE)
	check(paused and session.pause_menu.opened and not ui.minimap.visible,"pause hides minimap")
	await type_code()
	await press(KEY_M)
	check(not session.map_reveal_cheat and not ui.opened,"map and cheat stay inactive during pause")
	await press(KEY_ESCAPE)
	world.dialogue.start("forest_npc")
	await process_frame
	await type_code()
	await press(KEY_M)
	check(world.dialogue.active and not session.map_reveal_cheat and not ui.opened and not ui.minimap.visible,"dialogue blocks map, minimap and cheat")
	var attempts := 0
	while world.dialogue.active and attempts < 50:
		await press(KEY_Z)
		attempts += 1
	check(not world.dialogue.active,"existing dialogue navigation remains functional")
	var entrance_bits: String = session.exploration.snapshot().entrance
	await session.travel("deep_forest","FromEntrance")
	world = current_scene
	ui = world.map_ui
	await process_frame
	check(session.exploration.snapshot().entrance == entrance_bits,"legitimate Entrance exploration survives transition")
	check(ui.minimap.player_world == Layout.world_point("deep_forest",world.player.position),"region transition updates player marker transform")
	check(ui.minimap.player_world.x >= 200,"Deep Forest marker appears in northeast region")
	await press(KEY_M)
	check(ui.full_map.center_world == ui.minimap.player_world,"map recenters on destination region")
	await press(KEY_M)
	world.player.position = world.map.get_node("Discoveries/FarGlade").position
	check(session.save_current(),"save records newly explored far terrain")
	var saved: Dictionary = session.saves.read_save()
	var saved_bits: Dictionary = saved.exploration.duplicate()
	session.map_reveal_cheat = true
	session.exploration.reset()
	check(await session.load_game(),"save reload restores map state")
	await process_frame
	check(session.exploration.snapshot() == saved_bits,"all region exploration restores exactly after load")
	check(not session.map_reveal_cheat,"loading starts with ordinary fog, not cheat reveal")
	check(current_scene.player.position == Vector2(saved.position[0],saved.position[1]),"map save additions preserve original player position")
	# Inspect the existing item once awarded; the UI cannot itself grant it.
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await press(KEY_SPACE)
	check(current_scene.map_ui.inventory_contents.text == "Flooded Forest Key","inventory reflects the existing key reward")
	await press(KEY_SPACE)
	session.evil_bart_defeated = false
	session.story_flags = {"bart_defeated":false,"flooded_forest_key_obtained":false}
	await session.travel("bart_area","FromDeep")
	await session.begin_battle(Vector2(1000,520))
	check(current_scene.has_method("record_victory") and current_scene.get_node_or_null("Cartography") == null,"map UI is absent in boss fights")
	await type_code()
	await press(KEY_M)
	check(not session.map_reveal_cheat,"overworld reveal code does not activate during combat")
	# Leave a valid explored save for a separate process restart test.
	check(session.saves.write_save(saved),"leave explored V1 save for independent restart validation")
	current_scene.queue_free()
	await create_timer(0.25).timeout
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("CARTOGRAPHY VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
