extends RefCounted

const VERSION := 1
const AREA_SIZES := {"entrance": Vector2(1600, 900), "deep_forest": Vector2(1920, 1080), "bart_area": Vector2(1600, 900)}
var save_path: String = "user://save.json"
var last_error: String = ""

func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version") != VERSION:
		return {}
	var area: Variant = value.get("area")
	var position: Variant = value.get("position")
	if not area is String or not AREA_SIZES.has(area) or not position is Array or position.size() != 2:
		return {}
	for coordinate in position:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return {}
	var point := Vector2(position[0], position[1])
	var bounds: Vector2 = AREA_SIZES[area]
	if point.x < 44 or point.y < 44 or point.x > bounds.x - 44 or point.y > bounds.y - 44:
		return {}
	var defeated: Variant = value.get("evil_bart_defeated", false)
	var flags: Variant = value.get("story_flags", {})
	if not defeated is bool or not flags is Dictionary:
		return {}
	for flag in flags:
		if not flag is String or not flags[flag] is bool:
			return {}
	return {"version": VERSION, "area": area, "position": [float(point.x), float(point.y)], "evil_bart_defeated": defeated, "story_flags": flags.duplicate()}

func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return validate(json.data)

func read_save() -> Dictionary:
	last_error = ""
	var data := read_file(save_path)
	if data.is_empty():
		data = read_file(save_path + ".bak")
		if not data.is_empty():
			last_error = "Recovered the previous valid save."
	if data.is_empty():
		last_error = "No valid save found. The file may be missing, corrupt, or from an unsupported version."
	return data

func write_save(snapshot: Dictionary) -> bool:
	last_error = ""
	var data := validate(snapshot)
	if data.is_empty():
		last_error = "Progress could not be validated; the existing save was preserved."
		return false
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open the save directory for writing."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or read_file(temporary).is_empty():
		last_error = "The temporary save could not be verified."
		return false
	if not read_file(save_path).is_empty():
		error = DirAccess.copy_absolute(save_path, save_path + ".bak")
		if error != OK:
			last_error = "Could not preserve the previous save."
			return false
	error = DirAccess.rename_absolute(temporary, save_path)
	if error != OK:
		last_error = "Could not replace the save file (error %d)." % error
		return false
	return true
