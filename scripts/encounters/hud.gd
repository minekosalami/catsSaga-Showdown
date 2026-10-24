extends CanvasLayer
var battle: Node
var hp: ProgressBar
var enemy_name: Label
var status: Label
var player_hp: Label
var time_label: Label
var flee_button: Button
func _ready() -> void:
	layer=10
	battle=get_parent()
	var root =Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=preload("res://scripts/ui/sketch_theme.gd").create()
	var panel =VBoxContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left=20;panel.offset_right=-20;panel.offset_top=14
	enemy_name=Label.new()
	enemy_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	enemy_name.add_theme_font_size_override("font_size",20)
	panel.add_child(enemy_name)
	hp=ProgressBar.new()
	hp.show_percentage=false
	hp.custom_minimum_size.y=9
	panel.add_child(hp)
	var row =HBoxContainer.new()
	panel.add_child(row)
	player_hp=Label.new();player_hp.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(player_hp)
	time_label=Label.new();row.add_child(time_label)
	var bottom =HBoxContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=20;bottom.offset_right=-20;bottom.offset_top=-50;bottom.offset_bottom=-10
	var fight =Button.new()
	fight.text="FIGHT ["+get_node("/root/GameSettings").binding_label("attack")+"]"
	fight.focus_mode=Control.FOCUS_NONE
	fight.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fight.pressed.connect(func():
		if battle.player.shoot_timer<=0 and not battle.game_over and not battle.victory_started:
			battle.player.shoot();battle.player.shoot_timer=battle.player.SHOOT_INTERVAL)
	bottom.add_child(fight)
	flee_button=Button.new()
	flee_button.text="FLEE [V]"
	flee_button.focus_mode=Control.FOCUS_NONE
	flee_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	flee_button.pressed.connect(battle.attempt_flee)
	bottom.add_child(flee_button)
	status=Label.new()
	root.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top=-78
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",13)
func refresh() -> void:
	enemy_name.text=battle.Catalog.NAMES[battle.kind]
	hp.max_value=battle.boss.max_health;hp.value=battle.boss.health
	player_hp.text="HP %d/3   SATURATE %s"%[battle.player.health,"USED" if battle.player.saturate_used and not battle.player.unlimited_saturate else "READY"]
	time_label.text="%05.1fs"%maxf(0,battle.duration-battle.elapsed_time)
	flee_button.disabled=battle.flee_cooldown>0 or battle.game_over or battle.victory_started
func show_impact_flash() -> void: pass # Existing player/SATURATE already provide feedback.
