extends SceneTree

var session: Node
var menu: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func key(code: int, down := true, physical := 0, shifted := false, ctrl := false, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = physical
	event.shift_pressed = shifted
	event.ctrl_pressed = ctrl
	event.echo = echo
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(code: int, physical := 0, shifted := false) -> void:
	key(code,true,physical,shifted)
	await process_frame
	key(code,false,physical,shifted)
	await process_frame

func type_code(word: String) -> void:
	for letter in word.to_upper(): await press(letter.unicode_at(0))

func toggle() -> void:
	await press(KEY_MINUS,KEY_MINUS)
	await process_frame

func settle() -> void:
	while session.busy: await process_frame
	await physics_frame
	await process_frame
	await process_frame

func click(code: String) -> void:
	await click_button(menu.controls[code])

func click_button(button: Button) -> void:
	if menu.scroll.is_ancestor_of(button): menu.scroll.ensure_control_visible(button)
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
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-developer-menu.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	await session.new_game()
	await settle()
	menu = session.developer_menu
	var menu_id: int = menu.get_instance_id()
	check(InputMap.has_action("toggle_developer_menu") and InputMap.action_get_events("toggle_developer_menu").size() == 1 and InputMap.action_get_events("toggle_developer_menu")[0].physical_keycode == KEY_MINUS,"action binds only regular physical minus without Shift")
	await press(KEY_QUOTELEFT,KEY_QUOTELEFT)
	await press(KEY_ASCIITILDE,KEY_QUOTELEFT,true)
	check(not menu.opened and not paused,"old backtick and tilde shortcuts no longer open menu")
	check(menu.controls.size() == 15,"all five typed cheats, F3, eight stage seeks, and launch timestamp preview are listed")
	for code in session.developer_cheats.CODES: check(menu.controls.has(code),code+" appears in menu")
	await toggle()
	check(menu.opened and paused,"physical minus opens menu and pauses exploration")
	key(KEY_MINUS,true,KEY_MINUS,false,false,true)
	key(KEY_MINUS,false,KEY_MINUS)
	check(menu.opened,"key echo does not toggle menu")
	var point: Vector2 = current_scene.player.global_position
	key(KEY_D)
	await create_timer(.15).timeout
	key(KEY_D,false)
	check(current_scene.player.global_position == point,"gameplay movement is suspended under menu")
	check(menu.controls.CATA.disabled and menu.controls.BEAM.disabled and menu.controls["seek:0"].disabled,"combat-only cheats are disabled in exploration")
	await click("mycoordinates")
	check(menu.status.text == "X: %s | Y: %s" % [str(point.x),str(point.y)],"mouse coordinate action samples actual global position")
	var fog: Dictionary = session.exploration.snapshot()
	await click("thefogisleaving")
	check(session.map_reveal_cheat and menu.controls.thefogisleaving.button_pressed,"mouse fog toggle enables and reflects state")
	check(session.exploration.snapshot() == fog,"reveal cheat does not change saved exploration")
	await click("thefogisleaving")
	check(not session.map_reveal_cheat and not menu.controls.thefogisleaving.button_pressed,"mouse fog toggle disables")
	var flags: Dictionary = session.story_flags.duplicate()
	await click("anywhereiwant")
	check(session.unrestricted_region_access and menu.controls.anywhereiwant.button_pressed and session.story_flags == flags,"region toggle uses existing session override without story rewards")
	await type_code("anywhereiwant")
	check(session.unrestricted_region_access,"typing a code while menu is open cannot change toggles")
	await press(KEY_QUOTELEFT,KEY_QUOTELEFT)
	await press(KEY_ASCIITILDE,KEY_QUOTELEFT,true)
	check(menu.opened and paused,"old backtick and tilde shortcuts no longer close menu")
	await press(KEY_MINUS,KEY_MINUS)
	check(not menu.opened and not paused,"minus closes and resumes without Shift")
	await type_code("anywhereiwant")
	await type_code("thefogisleaving")
	await toggle()
	check(not menu.controls.anywhereiwant.button_pressed and menu.controls.thefogisleaving.button_pressed,"menu reflects changes from typed shortcuts")
	await press(KEY_ESCAPE)
	check(not menu.opened and not paused and not session.pause_menu.opened,"Escape closes developer menu without opening ordinary pause")
	var start: Vector2 = current_scene.player.position
	key(KEY_D)
	await create_timer(.15).timeout
	key(KEY_D,false)
	check(current_scene.player.position.x > start.x+10,"normal movement resumes after closing menu")
	await press(KEY_ESCAPE)
	check(paused and session.pause_menu.opened,"ordinary pause remains available")
	await toggle()
	check(menu.opened and paused,"developer menu can overlay existing pause")
	await toggle()
	check(paused and session.pause_menu.opened,"closing menu restores pre-existing pause state")
	await press(KEY_ESCAPE)
	await session.travel("flooded_forest","FromDeep")
	await settle()
	await toggle()
	check(menu.opened and menu.get_instance_id() == menu_id,"same menu instance works in Flooded Forest")
	await session.travel("underground_cave","FromFlooded")
	await settle()
	check(not menu.opened and not paused,"scene transition safely closes menu and restores processing")
	await toggle()
	check(menu.opened and menu.get_instance_id() == menu_id and not menu.controls.mycoordinates.disabled,"menu and coordinate action work underground")
	root.size = Vector2i(540,900)
	root.content_scale_size = Vector2i(540,900)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(menu.panel.get_global_rect()),"panel fits 540x900 window")
	await click_button(menu.overlay.find_child("Close",true,false))
	check(not menu.opened and not paused,"mouse Close button dismisses menu and resumes gameplay")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	await session.transition_to("res://scenes/combat_host.tscn",true)
	await settle()
	var battle: Node = current_scene.battle
	await type_code("CATA")
	await type_code("BEAM")
	await toggle()
	check(menu.opened and paused and menu.controls.CATA.button_pressed and menu.controls.BEAM.button_pressed,"Bart menu reflects original typed CATA and BEAM")
	var audio_time: float = battle.music_player.get_playback_position()
	var hp: int = battle.player.health
	await create_timer(.2).timeout
	check(absf(battle.music_player.get_playback_position()-audio_time) < .05,"boss soundtrack pauses with menu to preserve timeline")
	await type_code("CATA")
	await press(KEY_X)
	check(battle.player.invincible and battle.player.health == hp and not battle.player.saturate_used,"menu input cannot type combat cheats or activate SATURATE")
	await click("CATA")
	await click("BEAM")
	check(not battle.player.invincible and not battle.player.unlimited_saturate,"mouse toggles disable CATA and BEAM through shared methods")
	await click("hitbox")
	check(battle.player.debug_hitbox_enabled and menu.controls.hitbox.button_pressed,"F3 hitbox debug is available through menu")
	await toggle()
	await press(KEY_F3)
	await toggle()
	check(not menu.controls.hitbox.button_pressed,"menu reflects original F3 shortcut")
	await toggle()
	check(not paused and session.suspended_modes.is_empty(),"closing combat menu restores suspended processing modes")
	var before_resume: float = battle.music_player.get_playback_position()
	await create_timer(.15).timeout
	check(battle.music_player.get_playback_position() > before_resume,"soundtrack resumes after menu closes")
	await session.transition_to("res://scenes/boss2/combat_host.tscn",true)
	await settle()
	await toggle()
	await click("CATA")
	await click("BEAM")
	battle = current_scene.battle
	check(battle.player.invincible and battle.player.unlimited_saturate,"Boss2 inherits the same existing combat cheat states")
	await toggle()
	await press(KEY_X)
	check(not battle.player.saturate_used,"BEAM does not enable forbidden SATURATE in Boss2 survival fight")
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	await settle()
	await type_code("CATA")
	await toggle()
	battle = current_scene.battle
	check(menu.controls.CATA.button_pressed and menu.controls.BEAM.disabled and menu.controls.hitbox.disabled,"BlankKitten reflects typed CATA without introducing attacking abilities")
	await click("CATA")
	check(not battle.player.invincible,"menu can disable BlankKitten invincibility")
	for index in range(8):
		await click("seek:"+str(index))
		check(is_equal_approx(battle.elapsed_time,battle.Cue.STARTS[index]) and battle.development_run,"stage preview %d reuses existing seek without awarding progression" % index)
	menu.seek_time.value = 42.25
	await click("seek:custom")
	check(is_equal_approx(battle.elapsed_time,42.25),"launch timestamp preview supports existing arbitrary seek")
	var frozen: float = battle.elapsed_time
	var preview_audio: float = battle.music_player.get_playback_position()
	await create_timer(.2).timeout
	check(is_equal_approx(battle.elapsed_time,frozen),"preview remains paused while menu is open")
	check(absf(battle.music_player.get_playback_position()-preview_audio) < .05,"seeking while paused does not resume soundtrack under menu")
	await toggle()
	var resumed_audio: float = battle.music_player.get_playback_position()
	await create_timer(.15).timeout
	check(battle.music_player.get_playback_position() > resumed_audio and battle.elapsed_time > frozen,"preview soundtrack and authoritative timeline resume on close")
	key(KEY_7,true,0,true,true)
	key(KEY_7,false,0,true,true)
	check(battle.development_run and battle.elapsed_time >= 102.85 and battle.elapsed_time < 103.1,"original Ctrl+Shift+7 shortcut remains functional")
	await toggle()
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	await settle()
	await toggle()
	check(not menu.controls.CATA.button_pressed and not current_scene.battle.development_run,"new encounter retains original per-player cheat reset behavior")
	check(menu.get_instance_id() == menu_id and session.find_children("DeveloperMenu","",false,false).size() == 1,"scene changes never duplicate the developer menu")
	await toggle()
	for voice in get_nodes_in_group("combat_music"): voice.stop()
	for voice in root.get_node("Music").get_children():
		if voice is AudioStreamPlayer: voice.stop()
	await create_timer(.15).timeout
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("DEVELOPER MENU: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
