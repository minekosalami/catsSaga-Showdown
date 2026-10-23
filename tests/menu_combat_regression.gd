extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":
		push_error("Use an isolated XDG_DATA_HOME and CATSSAGA_TEST_PROFILE=1; this test writes fixture saves/settings.")
		quit(1)
		return
	create_timer(75).timeout.connect(func():push_error("Combat menu regression timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func key(code: Key,pressed: bool=true) -> void:
	var event := InputEventKey.new();event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func word(text: String) -> void:
	for letter in text:key(letter.unicode_at(0));key(letter.unicode_at(0),false)
func run() -> void:
	root.size=Vector2i(1280,720)
	var session: Node=root.get_node("Session")
	var settings: Node=root.get_node("GameSettings")
	await session.new_game()
	var world := current_scene
	var statue: Node2D=world.map.find_child("CatSaveStatue",true,false)
	world.player.position=statue.position+Vector2(0,58)
	session.open_save_point(statue);session.confirmation.confirmed.emit()
	await process_frame
	var saved := FileAccess.get_file_as_string(session.saves.slot_path(1))
	for id in ["bart","boss2","blankkitten"]:
		session.encounter_active=true
		session.encounter_id=id
		var path := "res://scenes/combat_host.tscn" if id=="bart" else "res://scenes/%s/combat_host.tscn"%id
		await session.transition_to(path)
		var host := current_scene
		var battle: Node=host.battle
		word("CATA")
		check(battle.player.invincible,id+" typed CATA preserved")
		if id!="blankkitten":
			word("BEAM")
			check(battle.player.unlimited_saturate,id+" typed BEAM preserved")
		if id=="boss2":
			key(KEY_X)
			await create_timer(.1).timeout
			check(battle.player.sprinting and not battle.player.saturate_used,"Endure keeps sprint and intentionally disabled SATURATE")
			key(KEY_X,false)
			var ability := InputEventJoypadButton.new();ability.button_index=JOY_BUTTON_B;ability.pressed=true
			Input.parse_input_event(ability);Input.flush_buffered_events()
			await create_timer(.1).timeout
			check(battle.player.sprinting and not paused,"controller B activates Endure ability without opening pause")
			ability.pressed=false;Input.parse_input_event(ability);Input.flush_buffered_events()
		if id=="bart":
			settings.bind_key("attack",KEY_Q)
			key(KEY_Q);await create_timer(.2).timeout;key(KEY_Q,false)
			check(battle.player.shoot_timer>0,"rebound attack actually fires")
			settings.bindings.clear();settings.install_actions()
			battle.music_player.seek(7.2)
			await create_timer(.2).timeout
			check(battle.boss_spawned and battle.boss.health==300,"Bart still spawns at existing music cue with 300 HP")
		if id=="blankkitten":
			var event := InputEventJoypadButton.new();event.button_index=JOY_BUTTON_DPAD_RIGHT;event.pressed=true
			Input.parse_input_event(event)
			var before: Vector2=battle.player.position
			await create_timer(.1).timeout
			check(battle.player.position.x>before.x,"controller movement works in Sequence")
			event.pressed=false;Input.parse_input_event(event)
		check(not session.save_current(),id+" rejects save in combat")
		session.open_pause()
		check(paused and session.pause_menu.opened,id+" pause is interactive")
		var clock: float=battle.elapsed_time
		var music: float=battle.music_player.get_playback_position()
		var player: Vector2=battle.player.position
		var projectile_positions := {}
		for node in get_nodes_in_group("enemy_bullets"):
			if node is Node2D:projectile_positions[node]=node.position
		await create_timer(.3).timeout
		check(is_equal_approx(battle.elapsed_time,clock) and battle.player.position==player,id+" clock/player paused")
		var frozen := true
		for node in projectile_positions:
			if is_instance_valid(node) and node.position!=projectile_positions[node]:frozen=false
		check(frozen,id+" projectiles paused")
		check(absf(battle.music_player.get_playback_position()-music)<.06,id+" soundtrack paused")
		session.close_pause()
		await create_timer(.25).timeout
		check(battle.elapsed_time>clock and battle.music_player.get_playback_position()>music,id+" clock/audio resume without seeking")
		var seconds: float=battle.music_player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
		check(absf(battle.elapsed_time-seconds)<.12,id+" combat remains synchronized with soundtrack")
		settings.set_value("shake",false)
		settings.set_value("flashing",true)
		if id=="bart":
			battle.shake_time=.2;battle.shake_strength=10;battle._update_screen_shake(.01)
			check(battle.position==battle.original_position,"camera-shake preference changes presentation only")
			battle.ui.show_impact_flash()
			check(battle.ui.entrance_flash.modulate.a==0,"reduced flashing suppresses SATURATE impact veil")
		settings.set_value("flashing",false)
		host.record_victory()
		check(FileAccess.get_file_as_string(session.saves.slot_path(1))==saved,id+" victory never autosaves")
		await session.load_game(1)
		check(not session.evil_bart_defeated and not session.story_flags.get(id+"_defeated",false),id+" reload discards unsaved victory")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("MENU COMBAT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
