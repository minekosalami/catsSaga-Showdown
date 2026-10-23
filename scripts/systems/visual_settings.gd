extends Node
signal changed
var reduced := false
var motion := .8
const PATH := "user://visual-options.cfg"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(PATH)==OK:
		reduced = bool(config.get_value("visuals","reduced",false))
		motion = clampf(float(config.get_value("visuals","motion",.8)),0,1)
func set_reduced(value: bool) -> void:
	reduced = value
	save()
func set_motion(value: float) -> void:
	motion = clampf(value,0,1)
	save()
func save() -> void:
	var config := ConfigFile.new()
	config.set_value("visuals","reduced",reduced)
	config.set_value("visuals","motion",motion)
	config.save(PATH)
	changed.emit()
