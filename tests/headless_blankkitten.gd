extends SceneTree
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var checks := 0
var failures := 0
var session: Node
func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func acknowledge(dialogue: Node) -> void:
	if not dialogue.is_revealed(): dialogue.advance()
	dialogue.advance()

func accessible(world: Node, npc: Node) -> bool:
	# Actual player-sized physics queries along a grid path from the existing
	# northern NPC clearing to BlankKitten's interaction radius.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = world.player.get_node("CollisionShape2D").shape
	query.collision_mask = 1
	query.exclude = [world.player.get_rid()]
	var pending: Array[Vector2i] = [Vector2i(56,30)]
	var seen := {pending[0]:true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		var point := Vector2(cell)*16+Vector2(8,8)
		if point.distance_to(npc.position) < 90:
			return true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+direction
			if next.x < 40 or next.x > 90 or next.y < 20 or next.y > 55 or seen.has(next): continue
			seen[next] = true
			query.transform = Transform2D(0,Vector2(next)*16+Vector2(8,8))
			if world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				pending.append(next)
	return false

func frozen_battle() -> Node:
	var battle: Node = current_scene.battle
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	battle.hazards.set_physics_process(false)
	return battle

func verify_keyboard(game: Node) -> void:
	game.rebuild_clock(15)
	game.player.set_physics_process(true)
	var initial: Vector2 = game.player.position
	press(KEY_RIGHT,true)
	await create_timer(0.1).timeout
	press(KEY_RIGHT,false)
	check(game.player.position.x > initial.x+15 and game.player.position.y == initial.y,"root keyboard arrows reach the portrait star's movement controller")
	press(KEY_Z,true)
	await create_timer(0.1).timeout
	check(game.player.position.y < initial.y-20,"root Z press reaches the star's variable jump input")
	press(KEY_Z,false)
	await create_timer(0.7).timeout
	check(game.player.grounded and game.player.position.y == initial.y,"root Z release shortens the jump and reliably lands")
	game.player.set_physics_process(false)

func verify_morphs(game: Node) -> void:
	var outline: int = game.presentation.outline_id
	for stage in range(1,8):
		var start: float = Cue.STARTS[stage]-Cue.MORPH
		game.rebuild_clock(start-0.001)
		var before: Rect2 = game.arena_rect
		game.advance_clock(start)
		check(game.state == game.State.ARENA_TRANSITION and game.player.transition_safe and game.player.movement_locked,"morph locks and protects star before cue "+str(stage))
		check(not game.hazards.damaging and game.arena_rect == before,"outgoing hazards immediately harmless; outline continuous "+str(stage))
		var from: Vector2 = game.player.position
		game.advance_clock(start+Cue.MORPH*0.5)
		var destination: Rect2 = Cue.BOXES[stage]
		check(game.arena_rect.position.is_equal_approx(before.position.lerp(destination.position,0.5)) and game.arena_rect.size.is_equal_approx(before.size.lerp(destination.size,0.5)),"halfway outline interpolation "+str(stage))
		check(game.player.position.is_equal_approx(from.lerp(game.safe_point(destination,Cue.GRAVITY[stage]),0.5)),"star moves smoothly to next stage "+str(stage))
		check(is_equal_approx(absf(game.presentation.spin_pivot.rotation),PI) and game.presentation.spin_direction == (1 if stage%2 else -1),"one alternating spin, first clockwise "+str(stage))
		var bob: Vector2 = game.presentation.bob_pivot.position
		game.advance_clock(start+Cue.MORPH*0.55)
		check(game.presentation.bob_pivot.position != bob,"musical bob continues during spin "+str(stage))
		game.advance_clock(Cue.STARTS[stage]-0.00001)
		check(game.arena_rect.position.distance_to(destination.position) < 0.001 and game.arena_rect.size.distance_to(destination.size) < 0.001,"morph finishes at boundary without a snap "+str(stage))
		game.advance_clock(Cue.STARTS[stage])
		check(game.stage == stage and game.arena_rect == destination and not game.player.movement_locked and game.presentation.spin_pivot.rotation == 0,"next stage starts on cue, normal orientation restored "+str(stage))
		check(game.presentation.outline_id == outline and game.presentation.visible,"same persistent visible outline across all boundaries")
		check(game.music_player.playing,"music never paused during morph "+str(stage))

func jump_apex(game: Node, release_after: float) -> float:
	game.rebuild_clock(89.14)
	game.player.invulnerability = 0
	var player: Node = game.player
	player.jump_requested = true
	var floor_y: float = player.position.y
	var minimum := floor_y
	for frame in 120:
		if frame == int(release_after*120): player.jump_released = true
		player.step(1.0/120,Vector2.ZERO)
		minimum = minf(minimum,player.position.y)
		if frame > 0 and player.grounded: break
	check(player.grounded and player.velocity.y == 0,"jump reliably lands on the floor")
	return floor_y-minimum

func hazards_and_movement(game: Node) -> void:
	var short := jump_apex(game,.025)
	var full := jump_apex(game,10)
	check(short > 10 and short < full*.5 and full > 80,"tap/hold jump preserved")
	game.player.jump_requested = true
	game.player.step(1.0/120,Vector2.ZERO)
	var previous_velocity: float = game.player.velocity.y
	game.player.jump_requested = true
	game.player.step(1.0/120,Vector2.ZERO)
	check(game.player.velocity.y > previous_velocity,"no air double jump")
	for stage in [1,6]:
		game.rebuild_clock(Cue.STARTS[stage])
		var arena: Rect2 = game.arena_rect
		var width: float = arena.size.x/8
		var grid: float = Cue.MEASURE if stage == 1 else Cue.HALF_MEASURE
		var previous: Dictionary = {}
		var masks := {}
		check(game.hazards.pillars.size() >= (10 if stage == 1 else 25),"varied scheduled pillar phrases")
		for pillar in game.hazards.pillars:
			masks[pillar.mask] = true
			check(absf(pillar.impact/grid-round(pillar.impact/grid)) < .00001,"every impact on precise musical grid")
			check(pillar.fall-pillar.warning >= .48 and pillar.gap.size.x > game.player.RADIUS*2+24,"telegraph and safe width include reaction / silhouette margins")
			check(pillar.impact+game.hazards.floor_hold+game.hazards.retract < Cue.STARTS[stage+1]-Cue.MORPH,"pillar clears before protected outgoing morph")
			for block in pillar.blocks:
				check(is_equal_approx(block.size.x,width) and is_equal_approx(fposmod(block.position.x-arena.position.x,width),0),"individual slabs align exactly to eight equal lanes")
			if not previous.is_empty():
				var travel: float = absf(pillar.gap.get_center().x-previous.gap.get_center().x)
				var window: float = pillar.fall-previous.impact-game.hazards.floor_hold-.04
				check(travel/game.player.speed+.18 < window,"safe corridor reachable including 180ms human reaction")
			previous = pillar
		check(masks.size() >= 6,"learnable masks vary beyond two blocks")
		var first: Dictionary = game.hazards.pillars[0]
		game.advance_clock(first.impact+.01)
		check(game.hazards.impact_log.has(first.impact) and not game.feedback.particles.is_empty(),"exact impact cue emits bounded cosmetic debris / smoke")
		var duplicate: Array = game.hazards.pillars.duplicate(true)
		game.rebuild_clock(Cue.STARTS[stage])
		check(game.hazards.pillars == duplicate,"retry reconstructs identical lane patterns")
	game.rebuild_clock(34.28)
	var shapes: Array = game.hazards.shapes_at(36)
	check(shapes.size() == 5 and shapes.filter(func(x): return x.has("circle")).size() == 1,"exactly one giant fireball and four walls")
	check(game.hazards.BALL_VISUAL_RADIUS*2 == game.arena_rect.size.x*.5 and game.hazards.BALL_RADIUS < game.hazards.BALL_VISUAL_RADIUS,"half-width fireball has intuitive smaller core")
	var box: Rect2 = game.arena_rect.grow(-game.hazards.BALL_VISUAL_RADIUS-game.hazards.WALL_DEPTH)
	var contained := true
	for i in 600: contained = contained and box.grow(.001).has_point(game.hazards.ball_position(34.28+i*.04))
	check(contained,"entire flame envelope bounces inside burning walls")
	game.player.invulnerability = 0
	var hp: int = game.player.health
	for wall in shapes.slice(1):
		game.player.position = wall.rect.get_center()
		game.player.previous_position = game.player.position
		game.hazards.last_clock = 36
		game.hazards.advance(36,true)
	check(game.player.health == hp-1,"wall contact immediate, shared iframes prevent multiple damage")
	game.rebuild_clock(68.57)
	var safe := true
	var crossed := false
	for i in 2400:
		var time := 68.57+i/120.0
		var beams: Array = game.hazards.shapes_at(time)
		var point: Vector2 = game.hazards.grid_pocket(time).get_center()
		for beam in beams:
			safe = safe and not game.hazards.circle_hits_rect(point,game.player.RADIUS,beam.rect)
			for other in beams:
				if not beam.warning and not other.warning and beam.axis != other.axis and beam.rect.intersects(other.rect): crossed = true
	check(safe and crossed,"intersecting beams maintain a moving fully safe player-sized pocket")
	game.rebuild_clock(89.14)
	for pair in game.hazards.jump_pairs():
		check(pair.gap > game.player.RADIUS*2+20 and pair.height < full,"paired opening accommodates complete hitbox / lower obstacle clearable")
		check(pair.height+pair.gap-game.player.RADIUS*2 < full,"ceiling rejects max-height jump exploit")
	game.rebuild_clock(15)
	game.player.health = 5
	game.player.invulnerability = 0
	game.player.take_damage()
	game.player.take_damage()
	check(game.player.health == 4,"exact one-HP damage with shared post-hit grace")
	game.advance_clock(33.53)
	game.player.invulnerability = 0
	game.player.take_damage()
	check(game.player.health == 4,"no damage during morph")
	check(not game.player.has_method("shoot") and not game.player.has_method("activate_saturate"),"survival star retains no attacking abilities")

func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-blankkitten.json"
	await session.new_game()
	await session.travel("deep_forest","FromEntrance")
	var world: Node = current_scene
	var npc: Node = world.map.get_node("Characters/BlankKitten")
	await physics_frame
	await physics_frame
	check(accessible(world,npc),"BlankKitten reachable with actual player-sized collision queries")
	check(npc.position == Vector2(824,800) and world.map.map_size == Vector2(5120,2880),"stable NPC placement; existing forest dimensions preserved")
	check(npc.get_node("Sprite2D").texture.resource_path.ends_with("normalKitten-transparent.png"),"NPC uses processed normal image with nearest filtering")
	world.player.position = npc.position+Vector2(50,30)
	await physics_frame
	await process_frame
	await process_frame
	press(KEY_Z,true)
	press(KEY_Z,false)
	await process_frame
	check(world.dialogue.active and world.pending_encounter == "blankkitten","existing Z interaction opens BlankKitten graph")
	check(world.dialogue.lines.size() == 2 and world.dialogue.lines[0].text == "You... COME HERE" and world.dialogue.lines[1].text == "Let me tell you something... I. HATE. COLOR!" and world.dialogue.choices.is_empty(),"exact two-line introduction, no choices or invented text")
	acknowledge(world.dialogue)
	check(world.dialogue.active and not session.busy,"first line does not prematurely enter battle")
	acknowledge(world.dialogue)
	check(session.busy and session.encounter_id == "blankkitten" and session.battle_walls.visible,"second line starts universal black walls")
	var old_position: Vector2 = world.player.position
	press(KEY_RIGHT,true)
	await create_timer(0.4).timeout
	press(KEY_RIGHT,false)
	check(world.player.position == old_position,"entry blocks overworld movement")
	press(KEY_Z,true)
	press(KEY_Z,false)
	check(session.encounter_id == "blankkitten","repeated Z cannot enter twice")
	while current_scene == null or current_scene == world: await process_frame
	var game: Node = current_scene.battle
	check(session.curtain.modulate.a > 0 and game.elapsed_time == 0 and game.state == game.State.ENTERING and not game.music_player.playing and game.process_mode == Node.PROCESS_MODE_DISABLED,"new battle initializes behind black with no audio/gameplay clock")
	while session.busy: await process_frame
	check(game.music_player.playing and game.elapsed_time < 0.1 and game.player.health == 5,"reveal starts music at zero and exactly five HP")
	check(current_scene.arena.size == Vector2i(540,900),"original portrait internal resolution preserved")
	game = frozen_battle()
	await verify_keyboard(game)
	verify_morphs(game)
	for time in [0.0,13.71,34.27999,34.28,61.71,68.56999,68.57,89.14,102.84999,102.85,130.28]:
		game.rebuild_clock(time)
		check(game.presentation.distortion == Cue.distortion_at(time),"correct appearance at "+str(time))
		check(is_equal_approx(game.presentation.fire_strength,Cue.fire_at(time)),"correct fire intensity at "+str(time))
	check(game.presentation.ART.size() == 4 and game.presentation.sprite.scale.x == game.presentation.sprite.scale.y,"four shared original-proportion processed textures")
	game.rebuild_clock(64)
	check(game.state == game.State.BREAK and not game.hazards.damaging and game.player.transition_safe and not game.player.movement_locked,"break is harmless and freely movable")
	hazards_and_movement(game)
	game.rebuild_clock(1)
	game.advance_clock(105)
	check(game.stage == 6 and game.stage_history.slice(-6) == [1,2,3,4,5,6],"forward skip crosses cues exactly once without old hazard backlog")
	game.advance_clock(105)
	check(game.stage_history.size() == 7,"repeated cue callback cannot duplicate stages")
	game.music_player.seek(3)
	game.last_audio_position = 100
	game.clock_initialized = true
	await create_timer(0.06).timeout
	game._physics_process(0.016)
	check(game.stage == 0 and game.elapsed_time < 3.2 and game.presentation.distortion == 0 and game.presentation.fire_strength == 0,"real backwards audio seek reconstructs intro, art and fire")
	game.rebuild_clock(20)
	game.player.transition_safe = false
	for i in 5:
		game.player.invulnerability = 0
		game.player.take_damage()
	check(game.game_over and not game.victory_started and game.player.health == 0 and game.hazards.stage == -1 and game.feedback.death_age >= 0,"five hits clear hazards and start unique death sequence; no accidental victory")
	await create_timer(.95).timeout
	check(not game.music_player.playing and game.ui.result.visible,"death fragments resolve into retry UI with faded audio")
	var old_game: WeakRef = weakref(game)
	var retry_scene_id: int = current_scene.get_instance_id()
	game.ui.retry_button.pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == retry_scene_id: await process_frame
	game = current_scene.battle
	check(game.player.health == 5 and game.stage == 0 and game.elapsed_time == 0 and not game.music_player.playing and game.presentation.distortion == 0 and game.presentation.fire_strength == 0,"Retry resets health, exact zero clock, stage, distortion and fire behind black")
	while session.busy: await process_frame
	check(old_game.get_ref() == null,"Retry frees the prior battle and hazard nodes")
	check(game.hazards.pillars.is_empty() and game.hazards.debris.is_empty() and game.presentation.spin_pivot.rotation == 0,"Retry has no old attacks, particles or spins")
	# Two additional retries exercise early-ended audio and full node cleanup.
	for repeat in 2:
		game = frozen_battle()
		game.advance_clock(50)
		game._on_music_finished()
		await create_timer(.22).timeout
		check(game.game_over and not game.victory_started and not game.music_player.playing,"unexpected early audio end fails safely without granting completion")
		var previous_id: int = current_scene.get_instance_id()
		var freed: WeakRef = weakref(game)
		game.ui.retry_button.pressed.emit()
		while current_scene == null or current_scene.get_instance_id() == previous_id or session.busy: await process_frame
		game = current_scene.battle
		check(freed.get_ref() == null and game.player.health == 5 and game.elapsed_time < 0.1 and game.hazards.get_child_count() == 2 and not game.hazards.ball_quad.visible and not game.hazards.wall_quad.visible,"repeated Retry frees previous scene and resets all state")
	game = frozen_battle()
	game.advance_clock(130.28)
	check(game.state == game.State.ENDING and not game.hazards.damaging and game.music_player.playing and not game.ui.ending_label.visible,"ending clears hazards, continues music and invents no dialogue")
	game.cue_sheet = game.cue_sheet.duplicate(true)
	game.cue_sheet.ending_lines.append("Test-only authored line")
	game.advance_clock(135)
	check(game.ui.ending_label.visible and game.ui.ending_label.text == "Test-only authored line","editable ending data displays without blocking endpoint")
	game.advance_clock(145.709)
	check(not game.victory_started and not session.story_flags.has("blankkitten_defeated"),"no early victory before 145.71 seconds")
	game.advance_clock(145.71)
	check(game.victory_started and game.state == game.State.VICTORY and game.presentation.fire_strength == 0 and game.presentation.bob_pivot.rotation == 0,"victory exactly at endpoint with fire completely gone")
	check(session.story_flags.get("blankkitten_defeated",false) and session.saves.read_save().story_flags.get("blankkitten_defeated",false),"completion flag saved using existing version-one save system")
	check(session.story_flags.size() == 1,"victory adds no new item, key or story rewards")
	var flags: Dictionary = session.story_flags.duplicate()
	game.finish_survival()
	check(session.story_flags == flags,"victory guarded against repeated callbacks")
	await create_timer(0.2).timeout
	check(not game.music_player.playing,"final MP3 tail fades and stops")
	game.ui.return_button.pressed.emit()
	while session.busy: await process_frame
	await physics_frame
	await physics_frame
	check(current_scene.name == "Overworld" and session.area_id == "deep_forest" and not current_scene.dialogue.active,"Return restores original forest with no invented dialogue")
	check(not current_scene.map.get_node("Characters/BlankKitten").can_interact(),"defeated NPC cannot automatically retrigger")
	var returning_world: Node = current_scene
	await session.begin_blankkitten_battle(current_scene.player.position)
	check(current_scene == returning_world and not session.busy,"completed encounter entry guard rejects a second NPC fight")
	await session.begin_encounter("missing-test","res://scenes/blankkitten/not-a-real-host.tscn",Vector2.ZERO,"test-only-not-completed")
	check(current_scene == returning_world and not session.encounter_active and not session.busy and not session.curtain.visible,"missing future encounter scene restores the world and clears entry locks")
	await session.begin_encounter("blankkitten","res://scenes/blankkitten/combat_host.tscn",Vector2.ZERO,"test-only-not-completed")
	game = frozen_battle()
	game.music_player.stream = null
	game._audio_failure("Test-only missing soundtrack")
	check(game.game_over and not game.victory_started,"missing audio cannot fabricate a survival victory")
	game.ui.menu_button.pressed.emit()
	while session.busy: await process_frame
	check(current_scene.scene_file_path == "res://scenes/main_menu.tscn","Main Menu navigation works")
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BLANKKITTEN VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
