extends SceneTree
var checks:=0
var failures:=0
var session: Node
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":quit(1);return
	create_timer(120).timeout.connect(func():push_error("Presentation tests timed out");quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func settle() -> void:
	await process_frame
	while session.busy:await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	session=root.get_node("Session")
	await session.new_game(3)
	session.story_flags["blankkitten_defeated"]=true
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		session.area_id=area
		session.forest_encounters.population[0]={"kind":0,"position":Vector2(1000,912),"home":Vector2(1000,912),"alive":true,"retreat":false,"ignore_until":0.0}
		session.forest_encounters.active={"id":0,"kind":0,"area":area,"position":Vector2(240,912),"settled":false}
		await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
		var host: Node=current_scene
		var ui: Node=host.rpg_ui
		var battle: Node=host.battle
		battle.player.invincible=true
		await process_frame;await process_frame
		check(battle.get_node("RegionBackdrop").region_id==area,"correct automatic regional background "+area)
		check(host.arena.size==Vector2i(540,900),"simulation size unchanged")
		check(is_equal_approx(host.arena_container.scale.x,.8),"center arena keeps original fit")
		check(ui.right.position.y+ui.right.size.y*ui.right.scale.y<=host.size.y+1,"status panel stays in window")
		check(ui.left.position.x+ui.left.size.x*ui.left.scale.x<host.arena_container.position.x,"items do not overlap arena")
		check(ui.live_grade.get_global_rect().end.y<=host.size.y+1,"large grade stays visible at bottom")
		check(ui.live_grade.get_global_rect().position.y>host.size.y*.60,"grade is bottom-anchored")
		check(ui.right.find_children("*","Label",true,false).all(func(label):return not label.text.contains("STREAK")),"streak timer absent from primary status")
		check(ui.live_grade.text=="S+" and ui.score_label.text=="100%","live perfect grade")
		session.rpg.total_exp=9500;ui.refresh()
		check(ui.level_label.text=="LV 20" and ui.exp_label.text.contains("MAXIMUM") and ui.exp_bar.value==ui.exp_bar.max_value,"maximum-level state is clear")
		session.rpg.total_exp=0;ui.refresh()
		ui.score.finished=true;ui.score.hits=1;ui.score.elapsed=10;ui.score.streak=0
		for pair in [[99.99,"A+"],[90.0,"A+"],[80.0,"A"],[70.0,"B"],[60.0,"C"],[40.0,"D"],[39.0,"F"]]:
			ui.score.completed_squares=pair[0]
			ui.refresh()
			check(ui.live_grade.text==pair[1],"live threshold "+pair[1])
			check(ui.score_label.text==load("res://scripts/rpg/score.gd").display(pair[0]),"accurate live percentage")
		ui.score.completed_squares=99.999999;ui.refresh()
		check(ui.live_grade.text=="A+" and ui.score_label.text=="99.99%","nonperfect never formatted as S+")
		ui.score.hits=0;ui.refresh()
		var alt:=InputEventKey.new();alt.keycode=KEY_ALT;alt.pressed=true;Input.parse_input_event(alt)
		await create_timer(.2).timeout
		check(ui.item_mode and ui.cursor.size.is_equal_approx(Vector2(4,40)),"cursor stays an overlay, never fills panel (mode=%s size=%s active=%s busy=%s paused=%s)"%[ui.item_mode,ui.cursor.size,ui.active(),session.busy,paused])
		check(ui.buttons.size()==3 and ui.buttons[0].amount.text=="×0","empty inventory remains informative")
		var age: float=battle.boss.age
		await create_timer(.1).timeout
		check(battle.boss.age>age and not paused,"presentation never pauses active combat")
		battle.player.health=9;ui.refresh()
		check(ui.hp_bar.value==9,"HP meter Range value remains exact")
		ui.hp_bar._process(.02)
		check(ui.hp_bar.shown<1 and ui.hp_bar.ghost>ui.hp_bar.shown,"secondary damage bar trails actual fill")
		var coins: int=session.story_progress.necoins
		battle.boss.take_damage(72)
		await process_frame
		check(ui.result.percent==100 and ui.result.grade==ui.live_grade.text,"live and final grade agree")
		var reward: int=session.rpg.total_exp
		ui.skip_results();await process_frame
		check(ui.result_panel.finished and ui.result_panel.percent.text=="100%","skipping reveals final score")
		check(ui.result_panel.continue_button.text.begins_with("CONTINUE"),"skip exposes continuation")
		ui.skip_results();ui.complete()
		check(session.rpg.total_exp==reward and session.story_progress.necoins==coins+10,"skipping cannot duplicate rewards")
		ui.close_results();await settle()
		check(current_scene.name=="Overworld","presentation preserves victory return")
		# Restore LV1 to make every region's HP/EXP presentation independently comparable.
		session.rpg.restore({})
	await session.main_menu()
	check(current_scene.menu_container.get_node("RecordsButton")!=null,"main menu keeps Records")
	current_scene._show_records();await process_frame
	check(current_scene.page_kind=="records","Records presentation opens")
	check(session.records.best.has("ordinary_0"),"new PB remains persisted")
	var scroll: ScrollContainer=current_scene.page.get_child(1)
	var rows: VBoxContainer=scroll.get_child(0)
	var last_row: Control=rows.get_child(rows.get_child_count()-1)
	last_row.grab_focus();await process_frame
	check(scroll.scroll_vertical>0,"Records keyboard focus scrolls to the selected row")
	var up:=InputEventKey.new();up.keycode=KEY_UP;up.pressed=true;Input.parse_input_event(up)
	await process_frame
	check(root.gui_get_focus_owner()!=last_row,"Records supports directional keyboard navigation")

	await session.travel("deep_forest","Start")
	session.story_progress.necoins=100
	var world: Node=current_scene
	var shop: Node=load("res://scripts/story/shop_screen.gd").new();shop.world=world;world.add_child(shop)
	world.dialogue.advance();world.dialogue.advance()
	check(world.dialogue.choice_buttons.size()==2,"shop dialogue choices are available")
	world.dialogue.choice_buttons[0].pressed.emit()
	await process_frame;await process_frame
	world.dialogue.advance();world.dialogue.advance()
	check(world.dialogue.choice_buttons.size()==5,"complete styled shop list")
	world.dialogue.choice_buttons[1].pressed.emit()
	await process_frame;await process_frame
	check(session.rpg.inventory.first_aid==1 and session.story_progress.necoins==50,"actual styled button purchases exactly one item")
	check(session.get_node("PurchaseNotification").text=="First Aid Kit purchased.","purchase confirmation preserves real item name")
	shop.close();await process_frame
	print("ALIVE UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
