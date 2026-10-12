extends "res://scripts/world/portal.gd"

## A later route, separate from the original portals and key-gated entrance.
@export_enum("bart_defeated", "boss2_defeated") var required_story_flag := "bart_defeated"
@export var route_label := "FOREST"

func can_travel() -> bool:
	return Session.region_access_allowed(Session.evil_bart_defeated and Session.story_flags.get("flooded_forest_key_obtained", false) and Session.story_flags.get(required_story_flag, false))

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_label()

func _process(_delta: float) -> void:
	_refresh_label()

func _refresh_label() -> void:
	var label: Label = $Label
	label.text = route_label + "\n[OPEN]" if can_travel() else route_label + "\n[LOCKED]"
	label.modulate = Color.WHITE if can_travel() else Color(0.65, 0.65, 0.65)

func _on_body_entered(body: Node) -> void:
	if can_travel() and body.is_in_group("overworld_player") and not Session.busy:
		travel_requested.emit(destination, entry)
