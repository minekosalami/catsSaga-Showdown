extends SceneTree
var checks := 0
var failures := 0
var session: Node
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":quit(1);return
	create_timer(150).timeout.connect(func():push_error("RPG integration timeout");quit(1))
	run.call_deferred()
func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;event.echo=echo
	Input.parse_input_event(event)
	await process_frame
func settle() -> void:
	await process_frame
	while session.busy:await process_frame
func start_ordinary() -> Node:
	var world: Node=current_scene;world.encounters.set_process(false)
	session.forest_encounters.population[0]={"kind":4,"position":Vector2(1000,912),"home":Vector2(1000,912),"alive":true,"retreat":false,"ignore_until":0.0}
	session.forest_encounters.active={"id":0,"kind":4,"area":session.area_id,"position":world.player.position,"settled":false}
	session.encounter_active=true;session.encounter_id="ordinary"
	await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
	return current_scene.battle
func run() -> void:
	session=root.get_node("Session")
	await session.new_game(3)
	while not current_scene.encounters.loaded:await process_frame
	check(session.rpg.level()==1 and session.rpg.max_hp()==20,"new game stats")
	session.story_progress.necoins=200
	for id in session.rpg.ITEMS:session.rpg.purchase(id,session.story_progress)
	session.rpg.inventory.shield_ring=3
	var battle: Node=await start_ordinary()
	var ui: Node=current_scene.rpg_ui
	check(battle.player.health==20 and not ui.item_mode and ui.buttons.size()==3,"shared UI and fresh HP")
	await key(KEY_ALT)
	check(ui.item_mode and battle.player.item_mode,"Alt enters items")
	await key(KEY_ALT,true)
	check(ui.item_mode,"key repeat cannot retoggle")
	var point: Vector2=battle.player.position
	var clock: float=battle.music_player.get_playback_position()
	var age: float=battle.boss.age
	Input.action_press("move_right");Input.action_press("attack")
	await create_timer(.25).timeout
	Input.action_release("move_right");Input.action_release("attack")
	check(battle.player.position==point,"item mode blocks movement")
	check(battle.boss.age>age and battle.music_player.get_playback_position()>clock and not paused,"enemy/music continue in items")
	var hp: int=battle.player.health;battle.player.take_damage(1)
	check(battle.player.health==hp-3 and ui.score.hits==1,"ordinary damage is 3 and breaks streak")
	battle.player.take_damage(1)
	check(battle.player.health==hp-3 and ui.score.hits==1,"overlap blocked by ordinary immunity")
	ui.selected=1;check(ui.use_selected() and battle.player.health==20,"item healing capped and usable")
	var protection: float=battle.player.invulnerability_timer
	check(protection<=1.5,"healing adds no extra protection")
	ui.selected=2;check(ui.use_selected(),"shield use")
	battle.player.invulnerability_timer=0
	battle.player.take_damage(1)
	check(battle.player.health==20 and ui.score.hits==1,"shield block preserves HP and streak")
	await create_timer(.2).timeout
	check(battle.player.shield_remaining<5 and battle.player.shield_remaining>4.7,"shield clock continues")
	check(ui.use_selected() and battle.player.shield_remaining==5,"ring refreshes five seconds")
	battle.player._process(5.01)
	check(battle.player.shield_remaining==0,"ring expires at five seconds")
	await key(KEY_ALT)
	check(not ui.item_mode and not battle.player.item_mode,"Alt restores battle controls")
	session.rpg.total_exp=50
	battle.boss.set_physics_process(false)
	battle.player.position=battle.boss.position+Vector2(0,100)
	battle.player.shoot()
	await create_timer(.25).timeout
	check(is_equal_approx(battle.boss.health,70.95) and is_equal_approx(battle.ui.hp.value,70.95),"fractional LV2 bullet damage and bar")
	var coins: int=session.story_progress.necoins
	battle.boss.take_damage(1000)
	await create_timer(.95).timeout
	check(ui.done and ui.result.exp==25 and ui.result.coins==10 and ui.result.percent<100,"graded ordinary victory")
	check(session.story_progress.necoins==coins+10 and is_instance_valid(ui.grade_label) and ui.grade_label.scale.is_equal_approx(Vector2.ONE),"reward and grade slam settled")
	var exp: int=session.rpg.total_exp
	ui.complete();battle.finish("victory")
	check(session.rpg.total_exp==exp and session.story_progress.necoins==coins+10,"duplicate victory callbacks safe")
	check(session.saves.read_slot(3).rpg.total_exp==exp,"victory automatically persisted")
	ui.close_results();await settle()
	check(current_scene.name=="Overworld","ordinary results Continue returns")
	var records_before: Dictionary=session.records.best.duplicate()
	battle=await start_ordinary()
	for seed in range(1,100):
		var probe := RandomNumberGenerator.new();probe.seed=seed
		if probe.randi_range(0,1)==0:battle.rng.seed=seed;break
	battle.attempt_flee();await settle()
	check(session.rpg.total_exp==exp and session.story_progress.necoins==coins+10 and session.records.best==records_before,"successful FLEE gives no EXP, coins or record")
	# Earned progress is newer than the manual checkpoint, and must survive death
	# and loading from disk (including quest, currency, feather and inventory).
	session.story_progress.accept_cupid();session.story_progress.acquire_wand(false)
	session.story_progress.collect_feather("entrance_white")
	session.forest_encounters.activate_checkpoint("entrance",Vector2(640,1226))
	session.persist_progress()
	var earned: Dictionary=session.story_progress.snapshot()
	var inventory: Dictionary=session.rpg.inventory.duplicate()
	battle=await start_ordinary();battle.player.take_damage(100)
	await settle()
	check(current_scene.name=="Overworld" and current_scene.player.position==Vector2(640,1226),"death checkpoint return")
	check(session.story_progress.snapshot()==earned and session.rpg.inventory==inventory and session.rpg.total_exp==exp,"death keeps earned state")
	check(session.records.best==records_before,"defeat creates no victory record")
	await session.load_game(3)
	check(session.story_progress.snapshot()==earned and session.rpg.total_exp==exp and session.rpg.inventory==inventory,"disk load keeps latest progress")
	# Shop interface uses the existing dialogue choices, wand and theft route.
	await session.travel("deep_forest","Start")
	var shop: Node = load("res://scripts/story/shop_screen.gd").new();shop.world=current_scene;current_scene.add_child(shop)
	current_scene.dialogue._finish("shop_buy");await process_frame;await process_frame
	check(current_scene.dialogue.graph.nodes.shop.choices.size()==4,"shop has three consumables and Back after wand acquisition")
	var shop_coins: int=session.story_progress.necoins
	var kits: int=session.rpg.inventory.first_aid
	current_scene.dialogue._finish("shop_item_first_aid");await process_frame;await process_frame
	check(session.story_progress.necoins==shop_coins-50 and session.rpg.inventory.first_aid==kits+1,"shop choice purchases one item")
	shop.close();await process_frame
	# Every boss uses the same live items/status/scoring component, preserving
	# its own victory controller and soundtrack. Endpoint seeks are not full runs.
	for id in ["bart","boss2","blankkitten"]:
		session.rpg.restore({});session.encounter_id=id;session.encounter_active=true
		var path: String="res://scenes/combat_host.tscn" if id=="bart" else "res://scenes/%s/combat_host.tscn"%id
		await session.transition_to(path,true)
		battle=current_scene.battle;ui=current_scene.rpg_ui
		check(battle.player.health==20 and ui.score.hits==0 and not ui.item_mode,"fresh boss RPG state "+id)
		session.rpg.inventory.first_aid=1;session.rpg.inventory.shield_ring=1
		battle.player.health=1
		check(session.rpg.use_item("first_aid",battle.player) and battle.player.health==20,"boss healing "+id)
		check(session.rpg.use_item("shield_ring",battle.player),"boss ring "+id)
		if id=="blankkitten":
			battle.player.transition_safe=false;battle.player.take_damage()
		else:battle.player.take_damage(1)
		check(battle.player.health==20 and ui.score.hits==0,"boss shield preserves streak "+id)
		if id=="bart":
			battle.music_player.seek(7);await create_timer(.25).timeout
			check(battle.boss_spawned,"Smoki still spawns to music")
			battle.boss.take_damage(300)
			await create_timer(1.4).timeout
		elif id=="boss2":battle.elapsed_time=battle.end_time;battle.finish_survival()
		else:battle.elapsed_time=battle.Cue.END;battle.finish_survival()
		await create_timer(.95).timeout
		check(ui.done and ui.result.percent==100 and ui.result.grade=="S+","perfect boss results "+id)
		check(ui.result.exp==session.rpg.REWARDS[id] and session.rpg.level()>1 and battle.player.health==session.rpg.max_hp(),"boss EXP/level-up full heal "+id)
		exp=session.rpg.total_exp
		current_scene.record_victory();check(session.rpg.total_exp==exp,"boss reward cannot duplicate "+id)
		ui.close_results();await settle()
		if current_scene.name!="Overworld":await session.transition_to("res://scenes/world/overworld.tscn")
	await session.main_menu()
	current_scene._show_records();await process_frame
	check(current_scene.page_kind=="records" and session.records.best.size()>=4,"main menu Records loaded")
	check(current_scene.go_back(),"Records back navigation")
	print("RPG BATTLES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
