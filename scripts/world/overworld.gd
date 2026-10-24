extends Node2D

const MAPS := {
	"entrance": preload("res://scenes/journey/forest_entrance.tscn"),
	"deep_forest": preload("res://scenes/journey/deep_forest.tscn"),
	"bart_area": preload("res://scenes/journey/bart_area.tscn"),
	"flooded_forest": preload("res://scenes/journey/flooded_forest.tscn")
}
## Recoverable source paths; inactive scenes are not initialized during play.
const ARCHIVED_MAP_PATHS := {
	"underground_cave": "res://scenes/world/underground_cave.tscn",
	"wonderland_forest": "res://scenes/wonderland/wonderland_forest.tscn",
	"tea_gardens": "res://scenes/wonderland/tea_gardens.tscn",
	"mushroom_thicket": "res://scenes/wonderland/mushroom_thicket.tscn",
	"royal_woods": "res://scenes/wonderland/royal_woods.tscn",
	"wonderland_village": "res://scenes/wonderland/wonderland_village.tscn",
	"queens_castle": "res://scenes/wonderland/queens_castle.tscn",
	"castle_hall": "res://scenes/wonderland/castle_hall.tscn",
	"royal_library": "res://scenes/wonderland/royal_library.tscn",
	"banquet_hall": "res://scenes/wonderland/banquet_hall.tscn",
	"throne_room": "res://scenes/wonderland/throne_room.tscn",
	"mushroom_cottage": "res://scenes/wonderland/mushroom_cottage.tscn",
	"teapot_house": "res://scenes/wonderland/teapot_house.tscn",
	"flower_shop": "res://scenes/wonderland/flower_shop.tscn",
	"clockmakers_house": "res://scenes/wonderland/clockmakers_house.tscn",
	"bakery": "res://scenes/wonderland/bakery.tscn",
	"royal_gift_shop": "res://scenes/wonderland/royal_gift_shop.tscn",
	"storytellers_cottage": "res://scenes/wonderland/storytellers_cottage.tscn",
	"tiny_pink_house": "res://scenes/wonderland/tiny_pink_house.tscn"
}
var map: Node2D
var player: CharacterBody2D
var dialogue: CanvasLayer
var pending_battle: bool = false
var interaction_hint: Label
var nearest_npc: Node2D
var interaction_indicator: Label
var conversation_flag: String = ""
var awaiting_victory_dialogue: bool = false
var checking_spawn: bool = false
var pending_encounter := "bart"
var encounters: Node
var story_shop: CanvasLayer
var automatic_encounter_pending := false
var coin_label: Label
var map_ui: CanvasLayer

func _ready() -> void:
	# Archived resources remain loadable in the editor, never as a playable save.
	if not preload("res://scripts/journey/layout.gd").active(Session.area_id):
		Session.area_id = "flooded_forest"
		Session.entry_marker = "Start"
		Session.restore_position = false
	map = MAPS[Session.area_id].instantiate()
	add_child(map)
	preload("res://scripts/story/world_content.gd").install(self)
	player = preload("res://scenes/world/player.tscn").instantiate()
	player.position = Session.return_position if Session.restore_position else map.get_node("Entries/" + Session.entry_marker).position
	checking_spawn = Session.restore_position
	Session.restore_position = false
	add_child(player)
	if not checking_spawn:
		player.face_direction(map.get_node("Entries/" + Session.entry_marker).get_meta("facing_direction", Vector2.LEFT))
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.map_size.x)
	camera.limit_bottom = int(map.map_size.y)
	if map.has_meta("camera_focus"): camera.position = map.get_meta("camera_focus")
	if map.has_meta("camera_bounds"):
		var bounds: Rect2 = map.get_meta("camera_bounds")
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.end.x)
		camera.limit_bottom = int(bounds.end.y)
	camera.reset_smoothing()
	camera.make_current()
	dialogue = preload("res://scenes/world/dialogue.tscn").instantiate()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	for portal in map.get_node("Portals").get_children():
		portal.travel_requested.connect(_travel)
	if not preload("res://scripts/journey/layout.gd").active(Session.area_id):
		preload("res://scripts/world/destination_sign.gd").install(map)
	preload("res://scripts/world/save_statue.gd").install(map)
	_build_hud()
	interaction_indicator = Label.new()
	interaction_indicator.name = "InteractionIndicator"
	interaction_indicator.text = "["+get_node("/root/GameSettings").binding_label("interact")+"]"
	interaction_indicator.add_theme_font_override("font", preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	interaction_indicator.add_theme_font_size_override("font_size", 18)
	interaction_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	interaction_indicator.add_theme_constant_override("outline_size", 6)
	add_child(interaction_indicator)
	interaction_indicator.hide()
	map_ui = CanvasLayer.new()
	map_ui.name = "Cartography"
	map_ui.set_script(preload("res://scripts/maps/map_ui.gd"))
	add_child(map_ui)
	map_ui.setup(self)
	encounters=preload("res://scripts/encounters/director.gd").new()
	encounters.name="ForestEncounters"
	add_child(encounters)
	if checking_spawn:
		player.movement_locked = true
		call_deferred("_validate_saved_position")
	awaiting_victory_dialogue = Session.area_id == "entrance" and Session.evil_bart_defeated and Session.story_flags.get("bart_victory_dialogue_pending", false) and not Session.story_flags.get("bart_victory_dialogue_seen", false)
	awaiting_victory_dialogue = awaiting_victory_dialogue or (Session.area_id == "flooded_forest" and Session.story_flags.get("boss2_defeated", false) and Session.story_flags.get("boss2_victory_dialogue_pending", false))
	if awaiting_victory_dialogue:
		player.movement_locked = true
		if Session.busy:
			Session.transition_finished.connect(_show_victory_dialogue, CONNECT_ONE_SHOT)
		else:
			call_deferred("_show_victory_dialogue")

	if Session.area_id=="bart_area" and not Session.story_flags.get("blankkitten_defeated",false):
		automatic_encounter_pending=true
		_start_blankkitten.call_deferred()

func _start_blankkitten() -> void:
	while Session.busy or checking_spawn:
		await get_tree().process_frame
	var npc=map.get_node_or_null("Characters/BlankKitten")
	if npc!=null and not Session.story_flags.get("blankkitten_defeated",false):npc.handle_interaction(self)
	automatic_encounter_pending=false

func _validate_saved_position() -> void:
	# Wait until the new map's bodies are registered with the physics world.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.transform = player.global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	if (map.has_method("is_walkable_position") and not map.is_walkable_position(player.position)) or not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		var marker := map.get_node_or_null("Entries/" + Session.entry_marker) as Marker2D
		if marker == null:
			marker = map.get_node("Entries").get_child(0) as Marker2D
		player.position = marker.position
		player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()
	player.get_node("Camera2D").force_update_scroll()
	checking_spawn = false

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	if preload("res://scripts/wonderland/layout.gd").regions().has(Session.area_id):
		root.theme.set_color("font_outline_color","Label",Color("#283340"))
		root.theme.set_constant("outline_size","Label",4)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 196 if side == "left" else 24)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var title := Label.new()
	title.text = "// " + map.display_name.to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var currency := VBoxContainer.new()
	row.add_child(currency)
	var balance := HBoxContainer.new()
	currency.add_child(balance)
	var icon := TextureRect.new()
	icon.texture=preload("res://scripts/story/assets.gd").coin()
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(24,24)
	balance.add_child(icon)
	coin_label=Label.new()
	coin_label.add_theme_font_size_override("font_size",16)
	balance.add_child(coin_label)
	Session.story_progress.changed.connect(_refresh_currency)
	_refresh_currency()
	var back := Button.new()
	back.text = "MAIN MENU"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(Session.request_main_menu)
	currency.add_child(back)
	interaction_hint = Label.new()
	root.add_child(interaction_hint)
	interaction_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interaction_hint.offset_top = -56
	interaction_hint.offset_bottom = -24
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_font_size_override("font_size",14)
	interaction_hint.text = ""

func _refresh_currency() -> void:
	coin_label.text="%d NeCoins"%Session.story_progress.necoins

func _process(_delta: float) -> void:
	player.movement_locked = automatic_encounter_pending or checking_spawn or dialogue.active or Session.busy or awaiting_victory_dialogue or Session.world_menu_open() or map_ui.typing_code()
	nearest_npc = null
	var closest := INF
	for npc in get_tree().get_nodes_in_group("interactables"):
		if not map.is_ancestor_of(npc) or not npc.can_interact():
			continue
		var distance: float = player.global_position.distance_to(npc.global_position)
		if distance <= npc.interaction_radius and distance < closest:
			closest = distance
			nearest_npc = npc
	interaction_hint.visible = not checking_spawn and not Session.world_menu_open() and not dialogue.active and not awaiting_victory_dialogue and not Session.busy and not get_tree().paused
	interaction_indicator.visible = nearest_npc != null and interaction_hint.visible
	interaction_indicator.text="["+get_node("/root/GameSettings").binding_label("interact")+"]"
	if nearest_npc != null:
		interaction_indicator.global_position = nearest_npc.global_position + nearest_npc.get_meta("interaction_offset", Vector2(-16, -96 if nearest_npc.has_meta("save_statue") else -62))
	interaction_hint.text = get_node("/root/GameSettings").binding_label("interact")+"  "+("Save" if nearest_npc.has_meta("save_statue") else "Interact") if nearest_npc != null else ""

func _input(event: InputEvent) -> void:
	if map_ui.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not automatic_encounter_pending and not checking_spawn and not get_tree().paused and not Session.world_menu_open() and not Session.busy and not dialogue.active and not awaiting_victory_dialogue and nearest_npc != null and event.is_action_pressed("interact") and not event.is_echo():
		if nearest_npc.has_method("handle_interaction") and nearest_npc.handle_interaction(self):
			get_viewport().set_input_as_handled()
			return
		if nearest_npc.starts_battle:Session.story_flags["smoki_interacted"]=true
		pending_encounter = "boss2" if nearest_npc.has_meta("boss2") else "bart"
		pending_battle = false
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
	var completed_victory := conversation_flag == "bart_victory_dialogue_seen"
	var completed_boss2 := conversation_flag == "boss2_victory_dialogue_seen"
	if not conversation_flag.is_empty():
		Session.story_flags[conversation_flag] = true
	conversation_flag = ""
	player.movement_locked = false
	if dialogue.outcome == "battle":
		pending_battle = true
		player.movement_locked = true
		if pending_encounter == "blankkitten":
			Session.begin_blankkitten_battle(player.position)
		elif pending_encounter == "boss2":
			Session.begin_boss2_battle(player.position)
		else:
			Session.begin_battle(player.position)
	elif completed_victory:
		Session.story_flags.erase("bart_victory_dialogue_pending")
	elif completed_boss2:
		Session.story_flags.erase("boss2_victory_dialogue_pending")

func _travel(destination: String, entry: String) -> void:
	if automatic_encounter_pending or checking_spawn or dialogue.active or Session.busy or awaiting_victory_dialogue or Session.world_menu_open() or get_tree().paused:
		return
	if Session.area_id=="entrance" and destination=="deep_forest" and not Session.region_access_allowed(Session.story_flags.get("smoki_interacted",false) or Session.evil_bart_defeated):
		Session.show_notification("Talk to Smoki first!")
		return
	player.movement_locked = true
	player.velocity = Vector2.ZERO
	if destination == "flooded_forest" and Session.story_flags.get("flooded_forest_key_obtained", false):
		Session.story_flags["flooded_forest_unlocked"] = true
	update_map_exploration()
	Session.travel(destination, entry)

func hide_interaction() -> void:
	interaction_indicator.hide()
	interaction_hint.hide()
	if map_ui != null: map_ui.minimap.hide()

func map_modal_open() -> bool:
	return is_instance_valid(story_shop) or (map_ui != null and map_ui.modal_open()) or (map != null and map.has_method("modal_open") and map.modal_open())

func update_map_exploration() -> void:
	if map_ui != null: map_ui.update_exploration()

func _show_victory_dialogue() -> void:
	if not awaiting_victory_dialogue or Session.busy:
		return
	awaiting_victory_dialogue = false
	var boss2 := Session.area_id == "flooded_forest"
	conversation_flag = "boss2_victory_dialogue_seen" if boss2 else "bart_victory_dialogue_seen"
	dialogue.start("boss2_victory" if boss2 else "bart_victory")
	player.movement_locked = true
	hide_interaction()
