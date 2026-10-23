extends "res://tests/render_forest_combat_overhaul.gd"
## Reuse the full world/three-boss capture suite, adding terrain and pose evidence.
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://render-extreme-opening.json"
	await session.new_game()
	await session.travel("bart_area","Start")
	await session.begin_battle(Vector2(1792,1000))
	await create_timer(3).timeout
	await super.snapshot("regular-combat",true)
	await session.main_menu()
	await super.run()
func snapshot(name: String,internal := false) -> void:
	await super.snapshot(name,internal)
	if name=="flooded-crossing":
		current_scene.player.position = Vector2(3456,2144)
		var camera: Camera2D = current_scene.player.get_node("Camera2D")
		camera.followed = current_scene.player.global_position
		camera.global_position = camera.followed
		camera.force_update_scroll()
		await create_timer(.12).timeout
		await super.snapshot("flooded-pond-bridge")
	elif name=="entrance":
		var actor: Node = current_scene.player
		for direction in [KEY_LEFT,KEY_RIGHT]:
			var event := InputEventKey.new()
			event.keycode = direction
			event.pressed = true
			Input.parse_input_event(event)
			await create_timer(.18).timeout
			await super.snapshot("player-left" if direction==KEY_LEFT else "player-right")
			event = InputEventKey.new()
			event.keycode = direction
			Input.parse_input_event(event)
		await create_timer(.3).timeout
		await super.snapshot("player-idle")
	elif name=="bart-climax":
		current_scene.battle.boss.take_damage(125)
		await create_timer(.04).timeout
		await super.snapshot("bart-impact",true)
	elif name=="doppelcat-cross":
		current_scene.battle.player.invincible = false
		current_scene.battle.player.take_damage(1)
		await create_timer(.06).timeout
		await super.snapshot("doppelcat-hit",true)
		current_scene.battle.player.invincible = true
	elif name=="sequence-showdown":
		var battle: Node = current_scene.battle
		for pillar in battle.hazards.pillars:
			if pillar.impact>battle.elapsed_time+.2:
				battle.seek_timestamp(pillar.impact-.18)
				battle.development_run = false
				await create_timer(.27).timeout
				await super.snapshot("sequence-impact",true)
				break
