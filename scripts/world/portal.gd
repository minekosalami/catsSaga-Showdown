extends Area2D

signal travel_requested(destination: String, entry: String)
@export_enum("entrance", "deep_forest", "bart_area", "flooded_forest") var destination: String = "entrance"
@export var entry: String = "FromDeep"

func _ready() -> void:
	body_entered.connect(func(body: Node):
		if body.is_in_group("overworld_player") and not Session.busy:
			travel_requested.emit(destination, entry)
	)
