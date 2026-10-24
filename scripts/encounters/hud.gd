extends CanvasLayer
const Style=preload("res://scripts/ui/presentation/style.gd")
var battle: Node
var hp: ProgressBar
var enemy_name: Label
var status: Label
var player_hp: Label
var time_label: Label
var flee_button: Button
var hp_caption: Label
var previous_status:=""
func _ready() -> void:
	layer=10;battle=get_parent()
	var root:=Control.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=Style.theme()
	var frame:=PanelContainer.new();root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	frame.offset_left=16;frame.offset_right=-16;frame.offset_top=12
	frame.add_theme_stylebox_override("panel",Style.box(Color("#102632f2"),Style.MINT,1,12))
	var panel:=VBoxContainer.new();panel.add_theme_constant_override("separation",4);frame.add_child(panel)
	var head:=HBoxContainer.new();panel.add_child(head)
	enemy_name=Style.label(head,"",23);enemy_name.add_theme_font_override("font",Style.BOLD)
	enemy_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	time_label=Style.label(head,"",18,Style.GOLD)
	hp=preload("res://scripts/ui/presentation/meter.gd").new();hp.tint=Style.CORAL;hp.custom_minimum_size.y=13;panel.add_child(hp)
	var row:=HBoxContainer.new();panel.add_child(row)
	hp_caption=Style.label(row,"",11,Style.MUTED);hp_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	player_hp=Style.label(row,"",11,Style.MINT)
	var bottom:=HBoxContainer.new();root.add_child(bottom)
	bottom.add_theme_constant_override("separation",10)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=16;bottom.offset_right=-16;bottom.offset_top=-52;bottom.offset_bottom=-10
	var fight:=preload("res://scripts/ui/presentation/button.gd").new()
	fight.text="FIGHT  ["+get_node("/root/GameSettings").binding_label("attack")+"]"
	fight.focus_mode=Control.FOCUS_NONE;fight.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fight.pressed.connect(func():
		if battle.player.shoot_timer<=0 and not battle.game_over and not battle.victory_started:
			battle.player.shoot();battle.player.shoot_timer=battle.player.SHOOT_INTERVAL)
	bottom.add_child(fight)
	flee_button=preload("res://scripts/ui/presentation/button.gd").new()
	flee_button.text="FLEE  [V]";flee_button.focus_mode=Control.FOCUS_NONE;flee_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	flee_button.pressed.connect(battle.attempt_flee);bottom.add_child(flee_button)
	status=Style.label(root,"",15,Style.GOLD)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);status.offset_top=-82;status.offset_bottom=-56
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func refresh() -> void:
	enemy_name.text=battle.Catalog.NAMES[battle.kind]
	hp.max_value=battle.boss.max_health;hp.value=battle.boss.health
	hp_caption.text="ENEMY HP  %.1f / %d"%[battle.boss.health,battle.boss.max_health]
	player_hp.text="SATURATE %s"%["USED" if battle.player.saturate_used and not battle.player.unlimited_saturate else "READY"]
	time_label.text="%05.1fs"%maxf(0,battle.duration-battle.elapsed_time)
	flee_button.disabled=battle.flee_cooldown>0 or battle.game_over or battle.victory_started
	if status.text!=previous_status and not status.text.is_empty():
		Style.pop(status,1.08);previous_status=status.text
func show_impact_flash() -> void:
	Style.pop(enemy_name,1.04)
