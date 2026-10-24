extends Control
## One host-side interface for every Showdown viewport. No world or audio clocks
## are paused by item navigation. Existing encounter controllers own victory.
const Score = preload("res://scripts/rpg/score.gd")
const Progress = preload("res://scripts/rpg/progress.gd")
const Records = preload("res://scripts/rpg/records.gd")
var host: Control
var battle: Node
var score := Score.new()
var item_mode := false
var alt_mode_before := false
var selected := 0
var done := false
var result: Dictionary = {}
var left: PanelContainer
var right: PanelContainer
var mode_label: Label
var status: Label
var hp_bar: ProgressBar
var exp_bar: ProgressBar
var buttons: Array[Button] = []
var result_panel: PanelContainer
var grade_label: Label
var continue_button: Button
var effects: CPUParticles2D
var result_elapsed := 0.0
var ids: Array = Progress.ITEMS.keys()

func _ready() -> void:
	host=get_parent();battle=host.battle
	process_mode=Node.PROCESS_MODE_PAUSABLE
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://scripts/ui/sketch_theme.gd").create()
	left=panel();right=panel()
	var items := column(left)
	mode_label=label(items,"BATTLE MODE · Alt: ITEMS",15)
	label(items,"ITEMS",26)
	for id in ids:
		var button := Button.new()
		button.custom_minimum_size.y=60
		button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(func():
			if item_mode: selected=ids.find(id);use_selected())
		items.add_child(button);buttons.append(button)
		label(items,Progress.ITEMS[id].effect,13)
	var stats := column(right)
	label(stats,"STATUS",26)
	status=label(stats,"",17)
	hp_bar=ProgressBar.new();hp_bar.show_percentage=false;hp_bar.custom_minimum_size.y=16;stats.add_child(hp_bar)
	exp_bar=ProgressBar.new();exp_bar.show_percentage=false;exp_bar.custom_minimum_size.y=10;stats.add_child(exp_bar)
	host.resized.connect(layout)
	layout()
	# The existing arena HUD keeps enemy HP, timers and encounter-specific cues.
	# Hide its old player-health card to avoid duplicate health interfaces.
	if "health_card" in battle.ui:
		battle.ui.health_card.hide()
		# Reuse the original live clock/stamina controls that shared that card.
		if "timer_label" in battle.ui:
			label(stats,"BATTLE CLOCK",13)
			battle.ui.timer_label.reparent(stats)
		if "current_phase_label" in battle.ui: battle.ui.current_phase_label.reparent(stats)
		if "stamina_bar" in battle.ui:
			battle.ui.stamina_caption.reparent(stats)
			battle.ui.stamina_bar.reparent(stats)
	if "health_label" in battle.ui: battle.ui.health_label.hide()
	if "health" in battle.ui and battle.ui.health is Label: battle.ui.health.hide()
	if battle.player.has_signal("hp_damaged"): battle.player.hp_damaged.connect(score.damage)
	refresh()

func panel() -> PanelContainer:
	var node := PanelContainer.new();add_child(node)
	node.add_theme_stylebox_override("panel",preload("res://scripts/ui/sketch_theme.gd").box(Color("#11151e"),Color("#9b91ae")))
	return node
func column(parent: Node) -> VBoxContainer:
	var margin := MarginContainer.new();parent.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	var node := VBoxContainer.new();node.add_theme_constant_override("separation",10);margin.add_child(node)
	return node
func label(parent: Node, text: String, font_size: int) -> Label:
	var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node);return node
func layout() -> void:
	# Keep the arena's established fit and aspect ratio. Side UI gets the actual
	# remaining columns, with a uniformly scaled layout on small windows.
	var edge: float = host.arena_container.position.x
	var width := maxf(1,edge-16)
	var panel_scale := minf(1,minf(width/240.0,host.size.y/600.0))
	left.scale=Vector2.ONE*panel_scale;right.scale=left.scale
	left.position=Vector2(8,24);right.position=Vector2(host.size.x-edge+8,24)
	left.size=Vector2(width/panel_scale,560);right.size=left.size
	if is_instance_valid(result_panel):
		var fit := minf(1,minf((host.size.x-24)/640.0,(host.size.y-24)/560.0))
		result_panel.scale=Vector2.ONE*fit
		result_panel.position=(host.size-Vector2(640,560)*fit)*0.5

func active() -> bool:
	return not done and not Session.busy and not Session.battle_entry_pending and not battle.game_over and not battle.victory_started
func handle_input(event: InputEvent) -> bool:
	if not active() or get_tree().paused: return false
	if event is InputEventKey and (event.keycode==KEY_ALT or event.physical_keycode==KEY_ALT):
		if event.pressed and not event.echo:
			alt_mode_before=item_mode
			item_mode=not item_mode
			battle.player.item_mode=item_mode
			battle.player.velocity=Vector2.ZERO
			refresh()
		return true
	if event is InputEventKey and event.alt_pressed and event.keycode==KEY_ENTER:
		item_mode=alt_mode_before
		battle.player.item_mode=item_mode
		return false
	if not item_mode: return false
	for action in ["move_up","move_left","move_down","move_right","attack","ui_accept","ability"]:
		if not event.is_action(action): continue
		if event.is_action_pressed(action) and not event.is_echo():
			if action in ["move_up","move_left"]: selected=posmod(selected-1,ids.size())
			elif action in ["move_down","move_right"]: selected=(selected+1)%ids.size()
			elif action in ["attack","ui_accept"]: use_selected()
		refresh()
		return true
	return false
func use_selected() -> bool:
	if not active() or not item_mode: return false
	var used := Session.rpg.use_item(ids[selected],battle.player)
	refresh()
	return used
func _process(delta: float) -> void:
	if active(): score.advance(delta)
	if is_instance_valid(result_panel):
		result_elapsed+=delta
		if result_elapsed>.8 and continue_button.disabled:
			continue_button.disabled=false
			continue_button.grab_focus()
	refresh()
func refresh() -> void:
	var progress: RefCounted=Session.rpg
	mode_label.text="ITEM MODE · Alt: BATTLE" if item_mode else "BATTLE MODE · Alt: ITEMS"
	for i in buttons.size():
		buttons[i].text=("> " if i==selected and item_mode else "")+Progress.ITEMS[ids[i]].name+" ×%d"%progress.inventory[ids[i]]
		buttons[i].disabled=not item_mode or not active() or progress.inventory[ids[i]]<=0 or (ids[i]!="shield_ring" and battle.player.health>=progress.max_hp())
	status.text="LV %d\nHP %d / %d\n\nEXP %d / %s\n\nSCORE %s\nSTREAK %.1fs\n\n%s"%[progress.level(),battle.player.health,progress.max_hp(),progress.total_exp,str(Progress.threshold(progress.level()+1)) if progress.level()<20 else "MAX",Score.display(score.percent()),score.streak,"SHIELD %.1fs"%battle.player.shield_remaining if battle.player.shield_remaining>0 else ""]
	hp_bar.max_value=progress.max_hp();hp_bar.value=battle.player.health
	exp_bar.min_value=Progress.threshold(progress.level())
	exp_bar.max_value=Progress.threshold(progress.level()+1) if progress.level()<20 else Progress.threshold(20)+1
	exp_bar.value=progress.total_exp if progress.level()<20 else exp_bar.max_value

func complete() -> void:
	if done: return
	done=true;score.finished=true;item_mode=false;battle.player.item_mode=false
	if ("practice_mode" in battle and battle.practice_mode) or ("development_run" in battle and battle.development_run): return
	var ordinary := "kind" in battle
	var id: String="ordinary_%d"%battle.kind if ordinary else ("blankkitten" if "practice_mode" in battle else ("boss2" if host.battle_scene.resource_path.contains("boss2") else ("incarna" if host.battle_scene.resource_path.contains("incarna") else "bart")))
	var pct := score.percent()
	var improved: bool=Session.records.improve(id,pct)
	if not Session.records.persist(): Session.show_notification("Records could not be saved.")
	if ordinary: Session.forest_encounters.reward_victory()
	result=Session.rpg.award(id,ordinary)
	result.merge({"id":id,"name":Records.NAMES.get(id,id.capitalize()),"percent":pct,"grade":Score.grade(pct),"coins":10 if ordinary else 0,"personal_best":improved})
	if result.level>result.level_before: battle.player.health=Session.rpg.max_hp()
	Session.persist_progress()
	show_results()
func show_results() -> void:
	result_panel=panel();result_panel.z_index=100;result_panel.size=Vector2(640,560)
	var stack := column(result_panel)
	label(stack,result.name+" · VICTORY()",25).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	grade_label=label(stack,result.grade,112)
	grade_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	grade_label.custom_minimum_size.y=160
	grade_label.pivot_offset=Vector2(300,80)
	var tint := Color("#ffe277") if result.grade=="S+" else Color.from_hsv(clampf(result.percent/140.0,0,0.7),.55,1)
	grade_label.modulate=tint
	label(stack,Score.display(result.percent)+"   ·   +%d EXP   ·   +%d NeCoins"%[result.exp,result.coins],22).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(stack,("NEW PERSONAL BEST!\n" if result.personal_best else "")+("LEVEL UP! LV %d → %d · HP %d"%[result.level_before,result.level,result.max_hp] if result.level>result.level_before else ""),20).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	continue_button=Button.new();continue_button.text="CONTINUE";continue_button.custom_minimum_size.y=52;continue_button.disabled=true
	continue_button.pressed.connect(close_results);stack.add_child(continue_button)
	layout()
	grade_label.scale=Vector2.ONE*3;grade_label.modulate.a=0
	var slam := create_tween()
	slam.tween_property(grade_label,"modulate:a",1.0,.10)
	slam.parallel().tween_property(grade_label,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_callback(func():
		var burst := CPUParticles2D.new();effects=burst;result_panel.add_child(burst)
		burst.position=Vector2(320,200);burst.one_shot=true;burst.explosiveness=1;burst.amount=48 if result.grade=="S+" else 24
		burst.lifetime=.6;burst.spread=180;burst.gravity=Vector2(0,90);burst.initial_velocity_min=60;burst.initial_velocity_max=220;burst.color=tint
		burst.emitting=not get_node("/root/VisualSettings").reduced
		if get_node("/root/GameSettings").values.shake:
			var shake := create_tween()
			for offset in [Vector2(4,0),Vector2(-4,2),Vector2(2,-2),Vector2.ZERO]:
				shake.tween_property(stack,"position",offset,.035))
func close_results() -> void:
	if not is_instance_valid(result_panel) or continue_button.disabled: return
	result_panel.queue_free();result_panel=null
	if result.id.begins_with("ordinary_"): Session.forest_encounters.resolve("victory")
	elif result.id=="blankkitten": Session.return_from_blankkitten()
