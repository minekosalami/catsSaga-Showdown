extends SceneTree
var session: Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func press(code: Key, window: Window = null) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		if window == null: Input.parse_input_event(event)
		else: window.push_input(event)
		await process_frame

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")

func bullet_probe(game: Node, offset: Vector2) -> Node:
	var bullet: Node = load("res://scenes/enemybullet.tscn").instantiate()
	bullet.speed = 0
	bullet.position = game.player.position + offset
	game.add_child(bullet)
	for i in range(4): await physics_frame
	await process_frame
	return bullet if is_instance_valid(bullet) else null

func run() -> void:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-controls-trees-hitbox.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path + suffix)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	var menu: Node = current_scene
	await press(KEY_X)
	check(current_scene == menu and menu.menu_container.visible, "X at main menu is nondisruptive")
	menu._show_info()
	await press(KEY_X)
	check(menu.menu_container.visible and menu.menu_container.get_node("InfoButton").has_focus(), "X returns Info to main menu with focus")
	menu._open_options()
	await process_frame
	await press(KEY_X, session.options_dialog)
	check(not session.options_dialog.visible and menu.menu_container.get_node("OptionsButton").has_focus(), "X closes focused Options window and restores main menu")
	var invoked := [false]
	session.confirm_action("Test cancel", func(): invoked[0] = true)
	await process_frame
	await press(KEY_X, session.confirmation)
	check(not is_instance_valid(session.confirmation) and not invoked[0], "X cancels confirmation without running action")
	menu.menu_container.get_node("StartButton").grab_focus()
	await press(KEY_DOWN)
	check(not menu.menu_container.get_node("StartButton").has_focus(), "arrows still navigate menu")
	menu.menu_container.get_node("StartButton").grab_focus()
	await press(KEY_Z)
	if session.busy: await session.transition_finished
	check(current_scene.name == "Overworld", "physical-key Z confirms Start after device mapping fix")
	var world: Node = current_scene
	await press(KEY_ESCAPE)
	await press(KEY_X)
	check(not paused and not session.pause_menu.opened, "X closes forest pause and resumes movement")
	await press(KEY_ESCAPE)
	session.open_options()
	await process_frame
	await press(KEY_X, session.options_dialog)
	check(paused and session.pause_menu.opened and not session.options_dialog.visible, "X closes pause Options without closing parent pause menu")
	await press(KEY_X)
	check(not paused, "next X resumes after leaving submenu")
	world.player.position = Vector2(450,335)
	await process_frame
	await process_frame
	await press(KEY_Z)
	check(world.dialogue.active and world.dialogue.speaker_label.text == "> TREE", "relocated inspectable tree retains Z and exact dialogue")
	var line: int = world.dialogue.line_index
	await press(KEY_X)
	check(world.dialogue.active and world.dialogue.line_index == line, "X cannot bypass required dialogue")
	while world.dialogue.active: await press(KEY_Z)
	# Inspect authored scenes and full visual bounds, not merely tree origins.
	for filename in ["forest_entrance", "deep_forest", "bart_area"]:
		var map: Node = load("res://scenes/world/" + filename + ".tscn").instantiate()
		var trees: Array = map.get_node("Trees").get_children()
		if filename == "forest_entrance": trees.append(map.get_node("Characters/InspectableTree/Tree"))
		var path: Node = map.get_node("PathPlaceholder")
		var path_rect := Rect2(path.position - path.box_size / 2, path.box_size)
		var above := 0
		var below := 0
		var clear := true
		var correct := true
		for tree in trees:
			var sprite: Sprite2D = tree.get_node("Sprite2D")
			var foot: Vector2 = tree.position
			if tree.get_parent().name == "InspectableTree": foot += tree.get_parent().position
			var rect := Rect2(foot + sprite.position, sprite.texture.get_size() * sprite.scale)
			clear = clear and not rect.intersects(path_rect)
			if foot.y < path_rect.position.y: above += 1
			else: below += 1
			correct = correct and sprite.texture.resource_path == "res://assets/enironment/tree.png" and sprite.scale.x == sprite.scale.y and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			var shape: CapsuleShape2D = tree.get_node("CollisionShape2D").shape
			correct = correct and shape.radius == 8 and shape.height == 24 and tree.collision_layer == 1
			# Keep sprite rectangles away from NPC visuals and spawn/portal positions.
			for npc in map.get_node("Characters").get_children():
				if npc.name != "InspectableTree": clear = clear and not rect.grow(16).has_point(npc.position)
			for entry in map.get_node("Entries").get_children(): clear = clear and not rect.grow(16).has_point(entry.position)
			for portal in map.get_node("Portals").get_children(): clear = clear and not rect.grow(16).has_point(portal.position)
		check(clear, filename + " full tree rectangles avoid path/NPC/entrances")
		check(correct, filename + " trees share unchanged image with uniform scale, nearest filtering and trunk-only collision")
		check(above >= (15 if filename == "deep_forest" else 5) and below >= (15 if filename == "deep_forest" else 5), filename + " clusters populate both sides of path")
		check(map.y_sort_enabled and map.get_node("Trees").y_sort_enabled and path.z_index < 0, filename + " depth sorting allows player behind canopy while path stays below")
		map.free()
	# Real CharacterBody motion into the inspection tree trunk.
	world.player.position = Vector2(450,335)
	var motion := InputEventKey.new()
	motion.keycode = KEY_W
	motion.pressed = true
	Input.parse_input_event(motion)
	await create_timer(0.3).timeout
	check(world.player.position.y >= 293 and world.player.get_slide_collision_count() > 0, "actual trunk collider blocks player approaching from below")
	motion = InputEventKey.new()
	motion.keycode = KEY_W
	Input.parse_input_event(motion)
	world.player.position = Vector2(485,300)
	motion = InputEventKey.new()
	motion.keycode = KEY_W
	motion.pressed = true
	Input.parse_input_event(motion)
	await create_timer(0.35).timeout
	check(world.player.position.y < 240, "player can move beside trunk beneath canopy instead of colliding with entire image")
	motion = InputEventKey.new()
	motion.keycode = KEY_W
	Input.parse_input_event(motion)
	await session.travel("bart_area", "FromDeep")
	world = current_scene
	world.player.position = Vector2(1000,520)
	await process_frame
	await process_frame
	await press(KEY_Z)
	world.dialogue.advance()
	world.dialogue.advance()
	await press(KEY_X)
	check(world.dialogue.node_id == "BART_001" and world.dialogue.choices.size() == 1 and not session.busy, "X cannot cancel mandatory What? or trigger fight")
	world.dialogue._finish("declined")
	await session.begin_battle(Vector2(1000,520))
	var game: Node = current_scene.battle
	game.set_process(false)
	game.player.set_process(false)
	var shape: CircleShape2D = game.player.get_node("CollisionShape2D").shape
	check(shape.radius == 5 and game.player.get_node("CollisionShape2D").position == Vector2.ZERO, "one authoritative damage circle centered at player with radius 5")
	check(game.player.get_children().filter(func(child): return child is CollisionShape2D).size() == 1, "no duplicate player damage shapes")
	var sprite: Sprite2D = game.player.get_node("Sprite2D")
	check(sprite.scale.is_equal_approx(Vector2(0.19719388,0.1398545)) and game.player.speed == 450 and game.player.focus_speed == 150, "battle sprite and movement speeds unchanged")
	var near: Node = await bullet_probe(game, Vector2(30,0))
	check(game.player.health == 3 and is_instance_valid(near), "real enemy bullet at distance 30 misses new hitbox (old hitbox would overlap)")
	check(is_equal_approx(near.get_node("CollisionShape2D").shape.radius,20.22375), "enemy bullet radius untouched")
	near.queue_free()
	await process_frame
	await bullet_probe(game, Vector2(22,0))
	check(game.player.health == 2 and game.player.invulnerability_timer > 0, "real intersecting projectile deals one damage and sets invulnerability")
	await bullet_probe(game, Vector2.ZERO)
	check(game.player.health == 2, "additional collision during invulnerability does not damage")
	game.player.invulnerability_timer = 0
	game.player.invincible = true
	await bullet_probe(game, Vector2.ZERO)
	check(game.player.health == 2, "CATA state continues to prevent damage")
	game.player.invincible = false
	game.player.damage_hitbox_radius = 6
	check(shape.radius == 6, "exported radius changes authoritative collision shape")
	var second: Node = load("res://scenes/player.tscn").instantiate()
	game.add_child(second)
	second.set_process(false)
	check(second.get_node("CollisionShape2D").shape.radius == 5 and second.get_node("CollisionShape2D").shape != shape, "hitbox tuning does not mutate other player instances")
	second.queue_free()
	await process_frame
	await bullet_probe(game, Vector2.ZERO)
	check(game.player.health == 1, "damage still applies after invulnerability expires")
	await press(KEY_X)
	check(game.player.saturate_used and not session.pause_menu.opened, "combat X still activates SATURATE")
	session.open_pause()
	await press(KEY_X)
	check(paused and session.pause_menu.opened, "combat pause X does not become forest back button")
	session.close_pause()
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("CONTROLS/TREES/HITBOX VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
