extends Area2D

signal travel_requested(destination: String, entry: String)
@export_enum("entrance", "deep_forest", "bart_area", "flooded_forest") var destination: String = "entrance"
@export var entry: String = "FromDeep"
@export var required_flag: String = ""

func can_travel() -> bool:
	return Session.region_access_allowed(required_flag.is_empty() or (Session.evil_bart_defeated and Session.story_flags.get(required_flag, false)))

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if can_travel() and body.is_in_group("overworld_player") and not Session.busy:
		travel_requested.emit(destination, entry)

func _process(_delta: float) -> void:
	if required_flag.is_empty(): return
	var label := get_node_or_null("DestinationLabel") as Label
	if label != null:
		label.text = "FLOODED FOREST\n[OPEN]" if can_travel() else "FLOODED FOREST\n[KEY REQUIRED]"
