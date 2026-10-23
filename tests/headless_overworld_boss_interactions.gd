extends SceneTree
## Actual overworld input path; isolated manual-save profile is mandatory.
var session: Node
var checks := 0
var failures := 0
var stages: Array[String] = []
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE") != "1":
		push_error("Use CATSSAGA_TEST_PROFILE=1 and isolated XDG_DATA_HOME.")
		quit(1)
		return
	create_timer(180).timeout.connect(func():push_error("Overworld encounter probe timed out");quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func key(code: Key,down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(code: Key) -> void:
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame
func settle() -> void:
	for frame in 3:await physics_frame
	await process_frame
func route_reaches_interaction(world: Node,npc: Node2D) -> bool:
	var step := 32.0
	var origin: Vector2=world.map.get_node("Entries/Start").position
	var first := Vector2i(origin/step)
	var pending: Array[Vector2i]=[first]
	var seen := {first:true}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=world.player.get_node("CollisionShape2D").shape
	query.collision_mask=world.player.collision_mask
	query.exclude=[world.player.get_rid()]
	var space: PhysicsDirectSpaceState2D=world.get_world_2d().direct_space_state
	var index := 0
	while index<pending.size():
		var cell := pending[index]
		index+=1
		var point := (Vector2(cell)+Vector2(.5,.5))*step
		if point.distance_to(npc.position)<npc.interaction_radius-8:return true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if seen.has(next):continue
			seen[next]=true
			var destination := (Vector2(next)+Vector2(.5,.5))*step
			if not Rect2(Vector2(48,48),world.map.map_size-Vector2(96,96)).has_point(destination):continue
			query.transform=Transform2D(0,destination)
			if space.intersect_shape(query,1).is_empty():pending.append(next)
	return false
func approach(id: String) -> Node:
	var world := current_scene
	var path: String={"bart":"EvilBart","boss2":"Boss2NPC","blankkitten":"BlankKitten"}[id]
	var npc: Node2D=world.map.get_node("Characters/"+path)
	check(route_reaches_interaction(world,npc),id+": player-sized collision route connects entry to NPC")
	# Begin beyond the interaction radius, then walk into it using actual input.
	world.player.position=npc.position+Vector2(0,npc.interaction_radius+40)
	world.player.velocity=Vector2.ZERO
	await settle()
	key(KEY_UP,true)
	await create_timer(.28).timeout
	key(KEY_UP,false)
	await create_timer(.1).timeout
	check(world.nearest_npc==npc,id+": movement reaches actual NPC interaction radius")
	check(world.interaction_indicator.visible and world.interaction_hint.visible,id+": actual interaction prompt appears")
	await tap(KEY_Z)
	check(world.dialogue.active,id+": Z opens existing encounter dialogue")
	return world
func finish_dialogue(world: Node,id: String) -> void:
	for i in 100:
		if not is_instance_valid(world) or session.busy or not world.dialogue.active:break
		if not world.dialogue.choices.is_empty() and id=="boss2" and world.dialogue.selected_choice==0:
			await tap(KEY_DOWN)
		await tap(KEY_Z)
	check(session.busy and session.battle_entry_pending,id+": dialogue confirmation starts protected entry")
	while session.busy:await process_frame
	await settle()
func record_stage(value: String) -> void:stages.append(value)
func enter(id: String) -> Node:
	stages.clear()
	var world := await approach(id)
	if not world.dialogue.active:return null
	await finish_dialogue(world,id)
	if not current_scene.has_method("record_victory"):return null
	check(stages.slice(stages.find("freeze"))==["freeze","blackout","cat_flash","loading","travel","star_flash","cat_return","reveal","idle"],id+": exact original entry stage order")
	var host := current_scene
	check(host.arena.size==Vector2i(540,900),id+": original internal battle resolution")
	check(host.battle.music_player.playing and host.battle.elapsed_time<.5,id+": soundtrack starts from zero after reveal")
	check(host.battle.player.can_process() and host.battle.player.health==(5 if id=="blankkitten" else 3),id+": controls active with original encounter HP after entry")
	check(not session.save_current(),id+": saving is rejected inside fight")
	return host
func manual_checkpoint() -> void:
	var world := current_scene
	var point: Node2D
	for object in get_nodes_in_group("interactables"):
		if object.has_meta("save_statue"):point=object;break
	world.player.position=point.position+Vector2(0,58)
	world.player.velocity=Vector2.ZERO
	await settle()
	await tap(KEY_Z)
	check(session.save_point_active and paused,"real Z save interaction before "+session.area_id)
	if not session.save_point_active:return
	session.confirmation.confirmed.emit()
	await process_frame
	check(not session.saves.read_slot(1).is_empty() and not paused,"manual checkpoint confirmed before "+session.area_id)
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("Session")
	session.battle_transition.stage_changed.connect(record_stage)
	await session.new_game(1)
	for info in [["bart","bart_area"],["blankkitten","deep_forest"],["boss2","flooded_forest"]]:
		var id: String=info[0]
		await session.travel(info[1],"Start")
		await manual_checkpoint()
		var before: Dictionary=session.saves.read_slot(1).story_flags.duplicate(true)
		var host := await enter(id)
		if host==null:continue
		var battle: Node=host.battle
		check(battle.music_player.stream.resource_path.ends_with({"bart":"fight.v.scale - catsSaga version.mp3","boss2":"SyNaPse - 003.mp3","blankkitten":"catVibes - 004.mp3"}[id]),id+": original encounter soundtrack selected")
		for hit in battle.player.health:
			if id=="blankkitten":battle.player.invulnerability=0; battle.player.transition_safe=false; battle.player.take_damage()
			else:battle.player.invulnerability_timer=0; battle.player.take_damage(1)
		await create_timer(.7).timeout
		check(battle.game_over,id+": actual player damage produces defeat")
		host.retry()
		while session.busy:await process_frame
		await settle()
		check(current_scene.name=="Overworld" and session.area_id==info[1],id+": defeat retry loads saved exploration region")
		check(session.story_flags==before and not session.encounter_active,id+": defeat restores checkpoint progression without granting victory")
		host=await enter(id)
		if host==null:continue
		battle=host.battle
		battle.player.invincible=true
		if id=="bart":
			battle.music_player.seek(7)
			await create_timer(.2).timeout
			check(battle.boss_spawned and battle.boss.health==300,"Bart: original spawn cue and exactly 300 HP")
			check(absf(battle.boss.elapsed-battle.music_player.get_playback_position())<.15,"Bart: spawned boss timeline remains synchronized to music")
			battle.boss.take_damage(battle.boss.health)
			await create_timer(1.4).timeout
			check(battle.victory_started and battle.ui.victory_screen.visible,"Bart: zero HP triggers existing defeat/victory sequence")
		else:
			var moment: float=13 if id=="boss2" else 17.3
			battle.music_player.seek(moment)
			await create_timer(.2).timeout
			check(absf(battle.elapsed_time-battle.music_player.get_playback_position())<.15,id+": encounter clock follows actual soundtrack seek")
			if id=="boss2":
				check(battle.timeline.phase==1 and get_nodes_in_group("enemy_bullets").size()>0,"Boss2: original first attacking phase emits projectiles")
				battle.music_player.seek(battle.end_time)
			else:
				check(battle.stage==1 and not battle.hazards.pillars.is_empty(),"BlankKitten: original first minigame phase configures hazards")
				battle.music_player.seek(battle.Cue.END-.05)
			await create_timer(.3).timeout
			check(battle.victory_started,id+": existing scripted ending triggers victory")
		check((session.evil_bart_defeated if id=="bart" else session.story_flags.get(id+"_defeated",false)),id+": confirmed victory updates existing progression")
		host.return_to_forest()
		while session.busy:await process_frame
		await settle()
		check(current_scene.name=="Overworld" and not session.encounter_active,id+": return restores free exploration")
		while current_scene.dialogue.active:await tap(KEY_Z)
		check(not current_scene.player.movement_locked,id+": exploration controls recover after existing post-battle dialogue")
	# The region bypass must not leave Boss2's accepted fight silently stalled.
	session.story_flags.erase("boss2_defeated")
	session.story_flags.erase("flooded_forest_key_obtained")
	session.unrestricted_region_access=false
	session.begin_boss2_battle(current_scene.player.position)
	await process_frame
	check(not session.busy and not session.encounter_active,"Boss2 still requires normal progression when override is disabled")
	session.unrestricted_region_access=true
	await session.travel("flooded_forest","Start")
	var world := await approach("boss2")
	if world.dialogue.active:
		for i in 8:
			if not world.dialogue.active:break
			if not world.dialogue.choices.is_empty() and world.dialogue.selected_choice==0:await tap(KEY_DOWN)
			await tap(KEY_Z)
		check(session.busy or current_scene.has_method("record_victory"),"debug unrestricted-region access does not silently reject the Boss2 challenge")
		while session.busy:await process_frame
	check(not session.story_flags.get("flooded_forest_key_obtained",false) and not session.story_flags.get("boss2_defeated",false),"debug entry grants neither key nor victory flags")
	if current_scene.name=="Overworld":check(not current_scene.player.movement_locked,"rejected encounter leaves player able to move")
	session.unrestricted_region_access=false
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("OVERWORLD BOSS INTERACTIONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
