extends Node2D

const MAPS := {
	"entrance": preload("res://scenes/world/forest_entrance.tscn"),
	"deep_forest": preload("res://scenes/world/deep_forest.tscn"),
	"bart_area": preload("res://scenes/world/bart_area.tscn")
}
var map: Node2D
var player: CharacterBody2D
var dialogue: CanvasLayer
var pending_battle: bool = false
var interaction_hint: Label
var nearest_npc: Node2D
var interaction_indicator: Label
var conversation_flag: String = ""

func _ready() -> void:
	map = MAPS[Session.area_id].instantiate()
	add_child(map)
	player = preload("res://scenes/world/player.tscn").instantiate()
	player.position = Session.return_position if Session.restore_position else map.get_node("Entries/" + Session.entry_marker).position
	Session.restore_position = false
	add_child(player)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.map_size.x)
	camera.limit_bottom = int(map.map_size.y)
	camera.reset_smoothing()
	camera.make_current()
	dialogue = preload("res://scenes/world/dialogue.tscn").instantiate()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	for portal in map.get_node("Portals").get_children():
		portal.travel_requested.connect(_travel)
	_build_hud()
	interaction_indicator = Label.new()
	interaction_indicator.name = "InteractionIndicator"
	interaction_indicator.text = "[E]"
	interaction_indicator.add_theme_font_override("font", preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	interaction_indicator.add_theme_font_size_override("font_size", 18)
	interaction_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	interaction_indicator.add_theme_constant_override("outline_size", 6)
	add_child(interaction_indicator)
	interaction_indicator.hide()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var title := Label.new()
	title.text = "// " + map.display_name.to_upper() + "  [TEMP MAP]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var back := Button.new()
	back.text = "MAIN MENU"
	back.pressed.connect(Session.request_main_menu)
	row.add_child(back)
	interaction_hint = Label.new()
	root.add_child(interaction_hint)
	interaction_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interaction_hint.offset_top = -56
	interaction_hint.offset_bottom = -24
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.text = "WASD / ARROWS  Move   |   SHIFT  Sprint   |   E  Interact   |   ESC  Pause"

func _process(_delta: float) -> void:
	player.movement_locked = dialogue.active or Session.busy
	nearest_npc = null
	var closest := INF
	for npc in get_tree().get_nodes_in_group("interactables"):
		if not map.is_ancestor_of(npc) or not npc.can_interact():
			continue
		var distance: float = player.position.distance_to(npc.position)
		if distance <= npc.interaction_radius and distance < closest:
			closest = distance
			nearest_npc = npc
	interaction_hint.visible = not dialogue.active and not Session.busy and not get_tree().paused
	interaction_indicator.visible = nearest_npc != null and interaction_hint.visible
	if nearest_npc != null:
		interaction_indicator.position = nearest_npc.position + Vector2(-16, -62)
	interaction_hint.text = "E  Interact" if nearest_npc != null else "WASD / ARROWS  Move   |   SHIFT  Sprint   |   E  Interact   |   ESC  Pause"

func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and not Session.busy and not dialogue.active and nearest_npc != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pending_battle = nearest_npc.starts_battle and not Session.evil_bart_defeated
		conversation_flag = nearest_npc.completion_flag
		var custom: Array = nearest_npc.custom_lines()
		if custom.is_empty():
			dialogue.start(nearest_npc.dialogue_key(), nearest_npc.typing_sound)
		else:
			dialogue.start_lines(custom, nearest_npc.typing_sound)
		hide_interaction()
		player.movement_locked = true
		get_viewport().set_input_as_handled()

func _on_dialogue_finished() -> void:
	if not conversation_flag.is_empty():
		Session.story_flags[conversation_flag] = true
	conversation_flag = ""
	player.movement_locked = false
	if pending_battle:
		pending_battle = false
		Session.begin_battle(player.position)

func _travel(destination: String, entry: String) -> void:
	if dialogue.active or Session.busy:
		return
	player.movement_locked = true
	Session.travel(destination, entry)

func hide_interaction() -> void:
	interaction_indicator.hide()
	interaction_hint.hide()
