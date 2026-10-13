extends SceneTree
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var checks := 0
var failures := 0
var output := "/workspace/.catsSaga-validation/blank-render"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(not img.is_empty(),name+" renders a nonempty viewport")
	img.save_png(output.path_join(name+".png"))
	return img
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-blank-render.json"
	await session.new_game()
	await session.travel("deep_forest","FromEntrance")
	var world: Node = current_scene
	world.player.position = Vector2(880,800)
	world.player.get_node("Camera2D").reset_smoothing()
	world.player.get_node("Camera2D").force_update_scroll()
	await capture("npc")
	world.map.get_node("Characters/BlankKitten").handle_interaction(world)
	world.dialogue.revealed = 999
	world.dialogue.text_label.visible_characters = -1
	await capture("intro-dialogue")
	world.dialogue.advance()
	world.dialogue.revealed = 999
	world.dialogue.text_label.visible_characters = -1
	await capture("hate-color-dialogue")
	world.dialogue.active = false
	world.dialogue.panel.hide()
	session.battle_transition.capture(world)
	await session.battle_transition.blackout()
	var entry: Image = await capture("entry-star")
	check(entry.get_pixel(0,0).r < 0.01 and entry.get_pixelv(entry.get_size()-Vector2i.ONE).r < 0.01,"star entry covers both window corners")
	session.battle_transition.clear(true)
	await session.begin_blankkitten_battle(world.player.position)
	var battle: Node = current_scene.battle
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	battle.hazards.set_physics_process(false)
	check(current_scene.arena.size == Vector2i(540,900),"internal viewport remains 540×900")
	for time in [0.7,15.0,15.43,33.905,34.28,36.0,63.0,68.8,70.0,74.7,79.0,84.0,89.4,90.9,94.2,96.0,102.84,103.2,104.0,104.57,105.0,111.42,128.0,128.57,130.28,140.0]:
		battle.rebuild_clock(time-0.4 if Cue.morph_at(time) >= 0 else time)
		battle.advance_clock(time)
		await capture("battle-"+str(time))
		current_scene.arena.get_texture().get_image().save_png(output.path_join("internal-"+str(time)+".png"))
		check(battle.ui.progress.size.y <= 4 and battle.ui.controls_label.get_rect().position.y > battle.ui.progress.get_rect().end.y,"controls and progress meter do not overlap")
		check(battle.player.position.x >= battle.arena_rect.position.x and battle.player.position.x <= battle.arena_rect.end.x,"star contained at "+str(time))
		var boss_bottom: float = battle.presentation.spin_pivot.position.y+battle.presentation.sprite.texture.get_height()*battle.presentation.sprite.scale.y/2+10
		check(boss_bottom < battle.arena_rect.position.y,"boss remains above box at "+str(time))
	root.content_scale_size = Vector2i(540,900)
	root.size = Vector2i(540,900)
	await process_frame
	await process_frame
	battle.rebuild_clock(105)
	await capture("portrait-showdown")
	var toggle: Control = battle.ui.effects_toggle
	var point: Vector2 = current_scene.arena_container.position+current_scene.arena_container.scale*toggle.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	check(battle.reduced_effects,"actual mouse input through host viewport activates Reduced FX")
	battle.advance_clock(105.2)
	await capture("reduced-showdown")
	check(battle.presentation.background_viewport.size == Vector2i(135,225) and current_scene.arena.size == Vector2i(540,900),"Reduced FX changes atmosphere resolution only")
	battle.ui.effects_toggle.button_pressed = false
	check(current_scene.arena_container.scale.is_equal_approx(Vector2.ONE) and current_scene.arena_container.position.is_equal_approx(Vector2.ZERO),"portrait window aligns the 540×900 arena exactly")
	session.battle_transition.capture(current_scene)
	await session.battle_transition.blackout()
	var portrait_black: Image = await capture("portrait-entry-black")
	check(portrait_black.get_pixel(0,0).r < 0.01 and session.battle_transition.size == Vector2(540,900),"encounter overlay covers portrait orientation")
	session.battle_transition.clear(true)
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	await process_frame
	await process_frame
	battle.advance_clock(Cue.END)
	await create_timer(0.4).timeout
	await capture("victory")
	await session.main_menu()
	await session.begin_encounter("blankkitten","res://scenes/blankkitten/combat_host.tscn",Vector2.ZERO,"test-never-completed")
	battle = current_scene.battle
	battle.advance_clock(15)
	battle.player.invulnerability = 0
	battle.player.health = 1
	battle.player.take_damage()
	await create_timer(.15).timeout
	await capture("death-fragments")
	check(battle.feedback.death_age >= 0 and not battle.feedback.particles.is_empty() and not battle.ui.result.visible,"rainbow fragments render before retry overlay")
	await create_timer(.95).timeout
	await capture("defeat")
	check(battle.ui.retry_button.visible and not battle.ui.return_button.visible,"defeat has Retry and Main Menu; Return restricted to victory")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BLANKKITTEN RENDER: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
