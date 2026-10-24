extends Control
## One host-side interface for every Showdown viewport. No world or audio clocks
## are paused by item navigation. Existing encounter controllers own victory.
const Art=preload("res://scripts/ui/presentation/style.gd")
const Meter=preload("res://scripts/ui/presentation/meter.gd")
const Card=preload("res://scripts/ui/presentation/item_card.gd")
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

var level_label: Label
var health_label: Label
var exp_label: Label
var score_label: Label
var live_grade: Label
var shield_label: Label
var item_hint: Label
var cursor: ColorRect
var previous_grade := ""
var previous_rank_value := 100.0
var previous_hp := -1
var previous_mode := false
var previous_selected := -1
var feedback_age := 0.0
var feedback_wait := 0.0
var result_dim: ColorRect
var health_observed := -1.0
var enemy_observed := -1.0

func _ready() -> void:
	host=get_parent();battle=host.battle
	process_mode=Node.PROCESS_MODE_PAUSABLE;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=Art.theme()
	left=panel();right=panel()
	left.accent=Art.MINT;right.accent=Art.LILAC
	var items:=column(left)
	label(items,"01 / INVENTORY",12,Art.MINT)
	label(items,"ITEMS()",30).add_theme_font_override("font",Art.BOLD)
	mode_label=label(items,"",13,Art.GOLD);mode_label.custom_minimum_size.y=28
	for id in ids:
		var button:=Card.new();button.item_id=id
		button.pressed.connect(func():if item_mode:selected=ids.find(id);use_selected())
		items.add_child(button);buttons.append(button)
	item_hint=label(items,"",13,Art.MUTED);item_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item_hint.custom_minimum_size.y=48
	var instructions:=label(items,"ALT   Switch controls\n↑ ↓   Choose item\nZ     Use selected item",12,Art.MUTED)
	instructions.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var cursor_layer:=Control.new();cursor_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;left.add_child(cursor_layer)
	cursor=ColorRect.new();cursor.color=Art.GOLD;cursor.size=Vector2(4,40);cursor.mouse_filter=Control.MOUSE_FILTER_IGNORE;cursor_layer.add_child(cursor)
	var stats:=column(right)
	label(stats,"02 / PLAYER STATUS",12,Art.LILAC)
	level_label=label(stats,"",31,Art.PAPER);level_label.add_theme_font_override("font",Art.BOLD);status=level_label
	health_label=label(stats,"",17)
	hp_bar=Meter.new();hp_bar.custom_minimum_size.y=18;stats.add_child(hp_bar)
	exp_label=label(stats,"",13,Art.LILAC)
	exp_bar=Meter.new();exp_bar.tint=Art.LILAC;stats.add_child(exp_bar)
	label(stats,"LIVE SCORE",12,Art.MUTED)
	score_label=label(stats,"",43,Art.PAPER);score_label.add_theme_font_override("font",Art.BOLD)
	shield_label=label(stats,"",13,Art.MINT);shield_label.custom_minimum_size.y=22
	if "health_card" in battle.ui:
		battle.ui.health_card.hide()
		if "timer_label" in battle.ui:
			var clock_title:=label(stats,"BATTLE CLOCK",11,Art.MUTED)
			battle.ui.timer_label.reparent(stats)
			battle.ui.timer_label.add_theme_font_size_override("font_size",17)
		if "current_phase_label" in battle.ui:battle.ui.current_phase_label.reparent(stats)
		if "stamina_bar" in battle.ui:
			battle.ui.stamina_caption.reparent(stats);battle.ui.stamina_bar.reparent(stats)
	if "health_label" in battle.ui:battle.ui.health_label.hide()
	if "health" in battle.ui and battle.ui.health is Label:battle.ui.health.hide()
	if not "health_card" in battle.ui:
		var encounter_card:=PanelContainer.new();encounter_card.add_theme_stylebox_override("panel",Art.box(Art.DEEP,Art.LILAC,1,8));stats.add_child(encounter_card)
		var encounter_row:=HBoxContainer.new();encounter_card.add_child(encounter_row)
		var encounter_id: String="ordinary_%d"%battle.kind if "kind" in battle else ("blankkitten" if "practice_mode" in battle else ("boss2" if host.battle_scene.resource_path.contains("boss2") else "bart"))
		var portrait:=TextureRect.new();portrait.texture=preload("res://scripts/ui/presentation/portraits.gd").texture(encounter_id)
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.custom_minimum_size=Vector2(84,100)
		encounter_row.add_child(portrait)
		preload("res://scripts/ui/presentation/portraits.gd").prepare(portrait,encounter_id)
		var encounter_name:=VBoxContainer.new();encounter_name.alignment=BoxContainer.ALIGNMENT_CENTER;encounter_row.add_child(encounter_name)
		label(encounter_name,"ENCOUNTER",10,Art.MUTED)
		label(encounter_name,Records.NAMES.get(encounter_id,encounter_id),15,Art.LILAC)
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;stats.add_child(spacer)
	var rank_caption:=label(stats,"CURRENT RANK",11,Art.MUTED);rank_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	live_grade=label(stats,"S+",106,Color.WHITE);live_grade.add_theme_font_override("font",Art.BOLD)
	live_grade.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;live_grade.custom_minimum_size.y=126
	if battle.player.has_signal("hp_damaged"):battle.player.hp_damaged.connect(score.damage)
	var player_feedback=preload("res://scripts/ui/presentation/player_effect.gd").new()
	player_feedback.player=battle.player;battle.add_child(player_feedback)
	host.resized.connect(layout);layout();refresh()

func panel() -> PanelContainer:
	var node=preload("res://scripts/ui/presentation/surface.gd").new();add_child(node)
	return node
func column(parent: Node) -> VBoxContainer:
	var node:=VBoxContainer.new();node.add_theme_constant_override("separation",9);parent.add_child(node);return node
func label(parent: Node, text: String, font_size: int, tint: Color=Art.PAPER) -> Label:
	return Art.label(parent,text,font_size,tint)
func layout() -> void:
	var edge: float=host.arena_container.position.x
	var width:=maxf(1,edge-24)
	var available:=host.size.y-32
	var panel_scale:=minf(1,minf(width/370.0,available/680.0))
	left.scale=Vector2.ONE*panel_scale;right.scale=left.scale
	left.position=Vector2(10,16);right.position=Vector2(host.size.x-edge+14,16)
	left.size=Vector2(width/panel_scale,available/panel_scale);right.size=left.size
	if is_instance_valid(result_panel):
		var fit:=minf(1,minf((host.size.x-32)/900.0,(host.size.y-32)/610.0))
		result_panel.scale=Vector2.ONE*fit
		result_panel.size=Vector2(900,610)
		result_panel.position=(host.size-Vector2(900,610)*fit)*.5

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
	buttons[selected].feedback(used)
	item_hint.text=("%s used." if used else "Cannot use %s now.")%Progress.ITEMS[ids[selected]].name
	feedback_wait=2.2
	if used:
		Art.burst(right,Vector2(30,120),Art.MINT,12)
	refresh()
	return used
func _process(delta: float) -> void:
	if active():score.advance(delta)
	feedback_wait=maxf(0,feedback_wait-delta)
	if is_instance_valid(result_panel):result_elapsed+=delta
	refresh()
	cursor.visible=item_mode and active()
	if cursor.visible:
		var point: Vector2=buttons[selected].global_position
		var local_point: Vector2=cursor.get_parent().get_global_transform().affine_inverse()*point
		cursor.position=cursor.position.lerp(Vector2(-5,local_point.y+30),1-exp(-delta*18))
	# Presentation observes health; it never changes movement, shapes or damage.
	if "boss" in battle and is_instance_valid(battle.boss) and "health" in battle.boss:
		var hp: float=battle.boss.health
		if enemy_observed>=0 and hp<enemy_observed and "sprite" in battle.boss:
			var sprite: Sprite2D=battle.boss.sprite
			if hp<=0 and "kind" in battle:
				var fade:=sprite.create_tween().set_parallel(true)
				fade.tween_property(sprite,"modulate:a",0.0,.26)
				fade.tween_property(sprite,"scale",sprite.scale*.9,.26)
				Art.burst(battle,battle.boss.position,Art.GOLD,12)
			elif not get_node("/root/GameSettings").values.flashing:
				sprite.modulate=Color(1.12,1.04,1.06)
				sprite.create_tween().tween_property(sprite,"modulate",Color.WHITE,.16)
		enemy_observed=hp
func refresh() -> void:
	var progress: RefCounted=Session.rpg
	mode_label.text="● ITEM MODE  /  ALT: BATTLE" if item_mode else "○ BATTLE MODE  /  ALT: ITEMS"
	mode_label.modulate=Art.MINT if item_mode else Art.MUTED
	for i in buttons.size():
		buttons[i].update_item(Progress.ITEMS[ids[i]].name,Progress.ITEMS[ids[i]].effect,progress.inventory[ids[i]],i==selected and item_mode)
		buttons[i].disabled=not item_mode or not active() or progress.inventory[ids[i]]<=0 or (ids[i]!="shield_ring" and battle.player.health>=progress.max_hp())
	if item_mode and selected!=previous_selected:
		Art.pop(buttons[selected],1.015,.18);previous_selected=selected
	if feedback_wait<=0:item_hint.text="Items remain live.\nCombat keeps moving in Item Mode."
	if item_mode!=previous_mode:
		Art.pop(mode_label,1.025);previous_mode=item_mode
	level_label.text="LV %02d"%progress.level()
	health_label.text="HP  %d / %d"%[battle.player.health,progress.max_hp()]
	var low: bool=battle.player.health<=progress.max_hp()*.3
	hp_bar.tint=Art.CORAL if low else Art.MINT
	hp_bar.max_value=progress.max_hp();hp_bar.value=battle.player.health
	if previous_hp>=0 and battle.player.health!=previous_hp:Art.pop(health_label,1.055)
	previous_hp=battle.player.health
	exp_bar.min_value=Progress.threshold(progress.level())
	exp_bar.max_value=Progress.threshold(progress.level()+1) if progress.level()<20 else Progress.threshold(20)+1
	exp_bar.value=progress.total_exp if progress.level()<20 else exp_bar.max_value
	exp_label.text="EXP  %d / %d"%[progress.total_exp-Progress.threshold(progress.level()),Progress.threshold(progress.level()+1)-Progress.threshold(progress.level())] if progress.level()<20 else "EXP  MAXIMUM LEVEL"
	var value:=score.percent();var current_grade:=Score.grade(value)
	score_label.text=Score.display(value)
	live_grade.text=current_grade;live_grade.modulate=Art.grade_color(current_grade)
	if current_grade!=previous_grade:
		if not previous_grade.is_empty():Art.pop(live_grade,1.12 if value>previous_rank_value else .94)
		previous_grade=current_grade
	previous_rank_value=value
	shield_label.text="SHIELD ACTIVE  %.1fs"%battle.player.shield_remaining if battle.player.shield_remaining>0 else "SHIELD  —  INACTIVE"

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
	result_dim=ColorRect.new();add_child(result_dim);result_dim.z_index=90
	result_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_dim.color=Color(Art.DEEP,0);result_dim.create_tween().tween_property(result_dim,"color:a",.88,.22)
	result_panel=preload("res://scripts/ui/presentation/results.gd").new();result_panel.data=result
	add_child(result_panel);result_panel.z_index=100
	result_panel.modulate.a=0
	result_panel.create_tween().tween_property(result_panel,"modulate:a",1.0,.18)
	grade_label=result_panel.grade;continue_button=result_panel.continue_button
	result_panel.advanced.connect(close_results)
	layout()
func skip_results() -> void:
	if is_instance_valid(result_panel):result_panel.skip()
func close_results() -> void:
	if not is_instance_valid(result_panel): return
	result_panel.queue_free();result_panel=null
	if is_instance_valid(result_dim):result_dim.queue_free()
	if result.id.begins_with("ordinary_"): Session.forest_encounters.resolve("victory")
	elif result.id=="blankkitten": Session.return_from_blankkitten()
