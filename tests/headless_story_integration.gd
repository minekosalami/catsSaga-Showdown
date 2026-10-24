extends SceneTree
var checks:=0
var failures:=0
var session: Node
var world: Node
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	create_timer(100).timeout.connect(func():push_error("Story test timeout");quit(1))
	run.call_deferred()
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func finish() -> void:
	for i in 20:
		if not world.dialogue.active or not world.dialogue.choices.is_empty():return
		world.dialogue.advance()
func choose(index: int) -> void:
	finish()
	check(not world.dialogue.choices.is_empty(),"choice present")
	world.dialogue._choose(index)
func interact(npc: Node) -> void:
	world.player.position=npc.global_position+Vector2(0,65)
	npc.handle_interaction(world)
func travel(area: String) -> void:
	await session.travel(area,"Start")
	world=current_scene
	await physics_frame
	await physics_frame
func run() -> void:
	session=root.get_node("Session")
	await session.new_game(3)
	world=current_scene
	check(world.player.position==Vector2(240,912),"original spawn preserved")
	world._travel("deep_forest","FromEntrance")
	check(session.area_id=="entrance" and session.get_node("DebugNotification").text=="Talk to Smoki first!","Smoki gate exact notification")
	world.player.position=Vector2(336,970)
	await process_frame
	var key:=InputEventKey.new();key.keycode=KEY_Z;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	await process_frame
	check(world.dialogue.active and session.story_flags.get("smoki_interacted",false),"Z talks to Smoki and unlocks gate")
	world.dialogue._finish("declined")
	var butter=world.map.get_node("Characters/Butterscotch")
	for option in [0,1,0]:
		interact(butter);choose(option);finish()
		check(not world.dialogue.active,"Butterscotch repeat conversation completes")
	await travel("deep_forest")
	check(world.map.get_node_or_null("Characters/BlankKitten")==null,"BlankKitten removed from Deep Forest")
	var cupid=world.map.get_node("Characters/Cupid")
	interact(cupid);choose(1);finish()
	check(not session.story_progress.cupid_accepted,"decline quest")
	interact(cupid);choose(0);finish()
	check(session.story_progress.cupid_accepted,"accept after decline")
	interact(cupid)
	check(world.dialogue.lines[0].text=="Have you found it yet? Have you found it yet?","waiting dialogue")
	finish()
	interact(world.map.get_node("Characters/PAWnShop"))
	var shop=world.story_shop
	check(is_instance_valid(shop) and world.map_modal_open(),"shop modal opens")
	choose(0);await process_frame;choose(0);await process_frame
	check(not session.story_progress.wand_owned and session.story_progress.necoins==0,"purchase rejected without money")
	choose(1);await process_frame;choose(0);await process_frame
	check(world.dialogue.lines.size()==2 and world.dialogue.lines[0].text=="Where does the cat go when he loses his tail??","two joke boxes")
	finish();await process_frame
	var camera=world.player.get_node("Camera2D")
	camera.reset_smoothing()
	var camera_position:Vector2=camera.global_position
	for steal in [false,false,true]:
		choose(1);await process_frame;choose(1);await process_frame
		finish();await create_timer(.8).timeout
		check(shop.keeper.position.x+shop.keeper.size.x<0,"keeper fully offscreen")
		check(camera.global_position==camera_position,"camera stationary")
		choose(0 if steal else 1)
		await create_timer(.8).timeout
		check(shop.keeper.position.is_equal_approx(shop.keeper_home),"keeper returns")
		check(session.story_progress.wand_owned==steal,"theft only on Yes")
	check(session.story_progress.necoins==0,"theft never spends coins")
	shop.close();await process_frame
	check(not world.map_modal_open(),"shop closes")
	interact(cupid);choose(1);finish()
	check(session.story_progress.necoins==75 and session.story_progress.cupid_completed,"quest reward75 integration")
	check(world.coin_label.text=="75 NeCoins","HUD updates immediately")
	interact(cupid);finish()
	check(session.story_progress.necoins==75,"repeat interaction no reward")
	var snapshot=session.snapshot("deep_forest",world.player.position)
	check(not snapshot.is_empty() and snapshot.story_progress.cupid_completed,"integrated state saves")
	# Both reward choices and paid purchase are independently tested from clean fixtures.
	session.story_progress.restore({})
	session.story_progress.necoins=9999
	interact(world.map.get_node("Characters/PAWnShop"))
	choose(0);await process_frame;choose(0);await process_frame
	check(session.story_progress.wand_owned and session.story_progress.necoins==0,"purchase exact deduction integration")
	world.story_shop.close();await process_frame
	interact(cupid);choose(0);finish()
	interact(cupid);choose(0);finish()
	check(session.story_progress.necoins==50,"quest reward50 integration")
	await travel("bart_area")
	await process_frame
	check(world.dialogue.active and world.pending_encounter=="blankkitten","automatic BlankKitten dialogue")
	world.dialogue._finish("")
	session.story_flags["blankkitten_defeated"]=true
	await travel("bart_area")
	check(world.map.get_node_or_null("Characters/BlankKitten")==null and not world.dialogue.active,"completed BlankKitten disappears without dialogue")
	await travel("flooded_forest")
	var boss=world.map.get_node("Characters/Boss2NPC")
	var bridges=world.map.get_node("Bridges")
	check(bridges.get_cell_source_id(bridges.local_to_map(boss.position))>=0,"Doppelcat on existing bridge")
	session.story_flags["boss2_defeated"]=true
	interact(boss)
	check(world.dialogue.lines[0].text=="You're not telling anyone about this","existing post-fight dialogue only")
	finish()
	var stars=0
	var colours=[]
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		await travel(area)
		for node in get_nodes_in_group("interactables"):
			if world.map.is_ancestor_of(node) and node.has_meta("save_statue"):stars+=1
		for item in load("res://scripts/story/world_content.gd").FEATHERS[area]:
			var feather=world.map.get_node(NodePath(item[0]))
			check(item[2] not in colours,"unique feather tint")
			colours.append(item[2])
			feather._collect(world.player)
			await process_frame
	check(stars==4,"exactly four stars")
	check(session.story_progress.feathers.size()==10 and session.story_progress.cat_toy,"world collection completes toy")
	check(session.get_node("FeatherNotification").text=="10/10 feathers collected!","collection notification")
	await travel("entrance")
	await process_frame
	check(world.map.get_node_or_null("entrance_white")==null,"collected feather absent on reentry")
	var saved:Dictionary=session.snapshot("entrance",world.player.position)
	check(session.saves.write_save(saved),"test fixture writes complete manual-save payload")
	session.story_progress.restore({})
	check(await session.load_game(3),"Continue loads complete story save")
	world=current_scene
	check(session.story_progress.cat_toy and session.story_progress.feathers.size()==10 and session.story_progress.necoins==50 and session.story_progress.cupid_completed,"Continue restores toy, feather IDs, currency and quest")
	session.story_flags.erase("blankkitten_defeated")
	await travel("bart_area")
	finish()
	while session.busy:await process_frame
	check(current_scene.has_method("record_victory") and session.encounter_id=="blankkitten","entry dialogue starts existing battle transition")
	var battle=current_scene.battle
	battle.finish_survival()
	check(not battle.victory_started,"BlankKitten cannot complete early")
	battle.elapsed_time=battle.Cue.END
	battle.finish_survival()
	await create_timer(.95).timeout
	current_scene.rpg_ui.close_results()
	await process_frame
	while session.busy:await process_frame
	world=current_scene
	check(world.name=="Overworld" and session.area_id=="bart_area" and session.story_flags.get("blankkitten_defeated",false),"victory returns automatically to Fluffy Forest")
	await physics_frame;await physics_frame;await process_frame
	check(not world.player.movement_locked and not world.dialogue.active and world.map.get_node_or_null("Characters/BlankKitten")==null,"victory grants control without extra dialogue or NPC")
	print("STORY INTEGRATION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
