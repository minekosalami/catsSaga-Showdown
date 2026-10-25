extends SceneTree
const Plan=preload("res://scripts/wonderland/layout.gd")
var Sequence: Script
var session: Node
var checks:=0
var failures:=0
var arrival_save:Dictionary
var capture:=false
var phases:Dictionary={}
var captured:Dictionary={}
func _initialize() -> void:
	capture=DisplayServer.get_name()!="headless"
	create_timer(160).timeout.connect(func():push_error("AMBUSH TIMEOUT");quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func click() -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
func screenshot(label: String) -> void:
	if not capture or captured.has(label):return
	captured[label]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/ambush/"+label+".png")
func drive(sequence: Node) -> void:
	while is_instance_valid(sequence):
		var phase:String=sequence.phase
		if not phases.has(phase):
			phases[phase]=true
			if phase=="taunt":
				check(sequence.enemies.size()==8,"All eight actors present")
				check(sequence.smoki==null,"Smoki absent before rescue")
				check(sequence.music.playing,"Song plays during taunt")
				check(sequence.music.stream.data==load(Sequence.SONG).data,"Approved soundtrack")
				for enemy in sequence.enemies:check(enemy is Sprite2D and enemy.get_child_count()==0,"Visual-only enemy cannot attack")
			if phase=="forest_landed":
				check(sequence.landed==8,"Eight enemies land without combat")
				for enemy in sequence.enemies:
					var probe:=PhysicsShapeQueryParameters2D.new()
					probe.shape=current_scene.player.get_node("CollisionShape2D").shape
					probe.transform=Transform2D(0,enemy.position);probe.collision_mask=1
					check(current_scene.get_world_2d().direct_space_state.intersect_shape(probe).is_empty(),"Enemy lands on clear ground")
			if phase=="departure":
				check(sequence.spoken.slice(-5)==Sequence.INTRO,"All five exact introduction lines")
				if sequence.spoken.size()>5:check(sequence.spoken.slice(0,5)==["Something seems off about this coin...","Look what we have here...","They all laugh at you, menacingly.","There's nowhere for you to run now!","Psst! Come with me!"],"Exact forest dialogue order")
			if phase=="introduction":
				arrival_save=session.saves.read_slot(1)
				check(arrival_save.get("area","")=="wonderland_forest","Arrival persisted in Wonderland")
				check(arrival_save.story_flags.wonderland_arrived and not arrival_save.story_flags.wonderland_intro_completed,"Arrival and completion saved separately")
				check(not session.encounter_active,"No battle on arrival")
				var probe:=PhysicsShapeQueryParameters2D.new()
				probe.shape=current_scene.player.get_node("CollisionShape2D").shape
				probe.transform=current_scene.player.global_transform;probe.collision_mask=1
				check(current_scene.get_world_2d().direct_space_state.intersect_shape(probe).is_empty(),"Arrival floor is clear")
				probe.transform=Transform2D(0,sequence.smoki.position)
				check(current_scene.get_world_2d().direct_space_state.intersect_shape(probe).is_empty(),"Smoki lands on clear ground")
			if phase in ["taunt","rescue","forest_landed","introduction"]:
				if sequence.world.dialogue.active:
					sequence.world.dialogue.revealed=10000
					await process_frame
				await screenshot(phase)
			if phase in ["explosion","arrival"] and capture:
				await create_timer(.65 if phase=="arrival" else .3).timeout
				await screenshot(phase)
		if is_instance_valid(sequence) and is_instance_valid(sequence.world) and sequence.world.dialogue.active:click()
		await create_timer(.16).timeout
func run() -> void:
	session=root.get_node("Session")
	Sequence=load("res://scripts/story/ambush.gd")
	await session.new_game()
	await session.travel("flooded_forest","FromBart")
	check(current_scene.map.get_node_or_null("AmbushTrap")==null,"Trap gated before Doppelcat")
	session.story_flags["boss2_defeated"]=true
	await session.travel("flooded_forest","FromBart")
	var trap=current_scene.map.get_node("AmbushTrap")
	check(trap.get_child_count()==6,"Coin plus five arrows")
	current_scene.player.position=trap.position+Vector2(0,85)
	await physics_frame;await physics_frame
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=current_scene.player.get_node("CollisionShape2D").shape
	query.transform=current_scene.player.global_transform;query.collision_mask=1
	check(current_scene.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"Trap interaction position is physically clear")
	var balance:int=session.story_progress.necoins
	trap.handle_interaction(current_scene)
	var sequence=session.get_child(session.get_child_count()-1)
	check(sequence.phase=="coin" and session.busy,"Coin locks movement and waits for input")
	session.request_main_menu()
	check(session.confirmation==null,"Unrelated menu cannot interrupt the sequence")
	await create_timer(.5).timeout
	check(sequence.phase=="coin","Dialogue never advances automatically")
	var echo:=InputEventKey.new();echo.keycode=KEY_Z;echo.pressed=true;echo.echo=true
	Input.parse_input_event(echo);Input.flush_buffered_events()
	check(sequence.spoken.size()==1,"Held-key echo cannot skip narration")
	check(not session.saves.read_slot(1).story_flags.wonderland_arrived,"Pre-arrival save retains replayable state")
	await drive(sequence)
	check(session.story_flags.get("wonderland_intro_completed",false),"Introduction completes")
	check(not session.busy and not session.story_sequence_active,"Controls unlocked")
	check(current_scene.player.visible and not current_scene.player.movement_locked,"Actual player restored")
	check(session.story_progress.necoins==balance,"Trap never grants currency")
	check(not current_scene.map.get_node("Portals/ToFlooded").can_travel(),"Destroyed portal cannot return")
	check(not session.story_flags.wonderland_fast_travel_unlocked,"Future travel remains locked")
	await session.load_game(1)
	check(session.area_id=="wonderland_forest" and not session.story_sequence_active,"Completed intro reloads without replay")
	# Exercise interrupted-arrival recovery from the actual earlier on-disk snapshot.
	session.saves.write_progress(arrival_save)
	await session.load_game(1)
	await create_timer(.1).timeout
	sequence=session.get_child(session.get_child_count()-1)
	check(sequence.get_script()==Sequence,"Interrupted introduction resumes")
	phases.clear()
	await drive(sequence)
	# Load every original map through the real current world wrapper.
	for id in Plan.regions():
		var packed:PackedScene=load("res://scenes/wonderland/"+id+".tscn")
		var map=packed.instantiate()
		var marker:String=map.get_node("Entries").get_child(0).name
		map.free()
		await session.travel(id,marker)
		await physics_frame
		check(session.area_id==id and current_scene.map.get_node_or_null("Ground")!=null,"Restored map loads: "+id)
		check(current_scene.encounters==null,"No new random encounters: "+id)
	# Return only for test inspection, not via a usable gameplay portal.
	session.area_id="flooded_forest";session.entry_marker="FromBart";session.restore_position=false
	await session.transition_to("res://scenes/world/overworld.tscn")
	check(current_scene.map.get_node_or_null("AmbushTrap")==null,"Trap permanently removed after return")
	var legacy=session.snapshot("wonderland_forest",Vector2(1280,1728))
	legacy.story_flags.erase("wonderland_arrived");legacy.story_flags.erase("wonderland_intro_completed")
	var migrated=session.saves.validate(legacy)
	check(migrated.area=="wonderland_forest" and migrated.story_flags.wonderland_intro_completed,"Legacy Wonderland location retained")
	print("AMBUSH: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
