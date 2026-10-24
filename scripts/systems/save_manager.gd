extends RefCounted

const VERSION := 1
const AREA_SIZES := {"entrance": Vector2(3200, 1824), "deep_forest": Vector2(5120, 2880), "bart_area": Vector2(3200, 1824), "flooded_forest": Vector2(4096, 3072), "underground_cave": Vector2(preload("res://scripts/world/cave_layout.gd").SIZE*32)}
var save_path: String = "user://save.json"
var last_error: String = ""
const SLOT_INDEX := "user://save-slots.cfg"
const LEGACY := "user://save.json"

func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("version") != VERSION:
		return {}
	var area: Variant = value.get("area")
	var position: Variant = value.get("position")
	var area_sizes := AREA_SIZES.duplicate()
	var extra_areas: Dictionary = preload("res://scripts/wonderland/layout.gd").regions()
	for id in extra_areas: area_sizes[id] = Vector2(extra_areas[id].size)*16
	if not area is String or not area_sizes.has(area) or not position is Array or position.size() != 2:
		return {}
	for coordinate in position:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return {}
	var point := Vector2(position[0], position[1])
	var defeated: Variant = value.get("evil_bart_defeated", false)
	var flags: Variant = value.get("story_flags", {})
	var legacy_bart: Variant = value.get("bart_defeated",false)
	if not defeated is bool or not legacy_bart is bool or not flags is Dictionary:
		return {}
	for flag in flags:
		if not flag is String or not flags[flag] is bool:
			return {}
	flags = flags.duplicate()
	var fog: Dictionary = value.get("exploration", {}).duplicate() if value.get("exploration",{}) is Dictionary else {}
	if not flags.get("cave_redesign_layout_v2",false):
		var old_cave: Variant = fog.get("underground_cave","")
		if not old_cave is String: return {}
		if old_cave.length() == 13656:
			var encoding := RegEx.new()
			encoding.compile("^[A-Za-z0-9+/]*={0,2}$")
			if encoding.search(old_cave) == null: return {}
			var decoded := Marshalls.base64_to_raw(old_cave)
			if decoded.size() != 10240: return {}
			for byte in decoded:
				if byte != 0: flags["underground_cave_discovered"] = true
			fog.erase("underground_cave")
		if area == "underground_cave":
			if point.x < 44 or point.y < 44 or point.x > 20436 or point.y > 16340: return {}
			point = preload("res://scripts/world/cave_layout.gd").ENTRY
			flags["underground_cave_discovered"] = true
		flags["cave_redesign_layout_v2"] = true
	# The settlement replaces the previous cave geometry, never unrelated progress.
	if not flags.get("cave_settlement_layout_v3",false):
		var previous: Variant = fog.get("underground_cave","")
		if not previous is String: return {}
		if previous.length() == 1596:
			var encoding := RegEx.new()
			encoding.compile("^[A-Za-z0-9+/]*={0,2}$")
			if encoding.search(previous) == null: return {}
			var decoded := Marshalls.base64_to_raw(previous)
			if decoded.size() != 1196: return {}
			for byte in decoded:
				if byte != 0: flags["underground_cave_discovered"] = true
			fog.erase("underground_cave")
		if area == "underground_cave":
			if point.x < 44 or point.y < 44 or point.x > 6612 or point.y > 5844: return {}
			point = preload("res://scripts/world/cave_layout.gd").ENTRY
			flags["underground_cave_discovered"] = true
		flags["cave_settlement_layout_v3"] = true
	var bounds: Vector2 = area_sizes[area]
	if point.x < 44 or point.y < 44 or point.x > bounds.x - 44 or point.y > bounds.y - 44: return {}
	# Version-one saves retain every unrelated flag; old Bart victories earn the key.
	defeated = defeated or legacy_bart or flags.get("bart_defeated", false)
	flags["bart_defeated"] = defeated
	flags["flooded_forest_key_obtained"] = defeated or flags.get("flooded_forest_key_obtained", false)
	for flag in ["flooded_forest_unlocked", "boss2_defeated"]:
		if not flags.has(flag):
			flags[flag] = false
	var exploration := preload("res://scripts/maps/exploration.gd").new()
	if not value.get("exploration",{}) is Dictionary or not exploration.restore(fog):
		return {}
	if defeated and not flags.has("bart_victory_dialogue_seen") and not flags.has("bart_victory_dialogue_pending"):
		flags["bart_victory_dialogue_seen"] = true
	# Preserve every archived flag/fog byte. Old saves load safely in the active
	# forest without rewriting or deleting the original file during read.
	var journey := preload("res://scripts/journey/layout.gd")
	if not journey.active(area):
		area = "flooded_forest"
		point = journey.SPAWNS[area]
	elif not flags.get(journey.REVISION,false):
		point = journey.SPAWNS[area]
	flags[journey.REVISION] = true
	var checkpoint: Variant=value.get("checkpoint", {"area":area,"position":[point.x,point.y]})
	if not checkpoint is Dictionary or not checkpoint.get("area","") in journey.ORDER:return {}
	var checkpoint_position: Variant=checkpoint.get("position")
	if not checkpoint_position is Array or checkpoint_position.size()!=2:return {}
	for axis in 2:
		var coordinate: Variant=checkpoint_position[axis]
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or coordinate<44 or coordinate>journey.SIZES[checkpoint.area][axis]-44:return {}
	var progress := preload("res://scripts/story/progress.gd").validate(value.get("story_progress",{}))
	if progress.is_empty(): return {}
	var playtime: Variant = value.get("playtime",0.0)
	if not (playtime is float or playtime is int) or not is_finite(float(playtime)) or playtime<0:return {}
	return {"playtime":float(playtime), "version": VERSION, "area": area, "position": [float(point.x), float(point.y)], "evil_bart_defeated": defeated, "story_flags": flags.duplicate(), "story_progress":progress, "checkpoint":checkpoint.duplicate(true), "exploration": exploration.snapshot()}

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
	if FileAccess.file_exists(save_path) and read_file(save_path).is_empty() and not FileAccess.file_exists(save_path+".invalid.bak"):
		if DirAccess.copy_absolute(save_path,save_path+".invalid.bak")!=OK:
			last_error="Could not preserve the unreadable save; replacement cancelled."
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

func slot_path(slot: int) -> String:
	return "user://save-slot-%d.json"%slot
func read_slot(slot: int) -> Dictionary:
	if slot<1 or slot>3:return {}
	last_error=""
	var data := read_file(slot_path(slot))
	if data.is_empty():
		data=read_file(slot_path(slot)+".bak")
		if not data.is_empty():last_error="Recovered the previous valid save for Slot %d."%slot
	return data
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot)+".bak")
func select_slot(slot: int) -> void:
	save_path=slot_path(slot)
func mark_used(slot: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SLOT_INDEX)
	cfg.set_value("slots","last_used",slot)
	var error := cfg.save(SLOT_INDEX+".tmp")
	if error==OK:error=DirAccess.rename_absolute(SLOT_INDEX+".tmp",SLOT_INDEX)
	if error!=OK:push_warning("Could not remember the last-used save slot.")
func most_recent_slot() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SLOT_INDEX)
	var last: int=int(cfg.get_value("slots","last_used",0))
	if not read_slot(last).is_empty():return last
	var selected := 0
	var newest := -1
	for slot in range(1,4):
		if read_slot(slot).is_empty():continue
		var modified := int(FileAccess.get_modified_time(slot_path(slot)))
		if modified>newest:selected=slot;newest=modified
	return selected
func migrate_legacy() -> String:
	# Never replace an occupied slot or alter/delete the source single-save file.
	var backup := LEGACY+".pre-slots.bak"
	var index := ConfigFile.new()
	index.load(SLOT_INDEX)
	if index.get_value("slots","legacy_migrated",false):return ""
	if not FileAccess.file_exists(LEGACY) and not FileAccess.file_exists(LEGACY+".bak"):return ""
	var data := read_file(LEGACY)
	var source := LEGACY
	if data.is_empty():data=read_file(LEGACY+".bak");source=LEGACY+".bak"
	if data.is_empty():return "The old save is unreadable. It has been preserved at user://save.json."
	for slot in range(1,4):
		if slot_exists(slot):continue
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(source,backup)!=OK:return "Could not back up the old save. It was left untouched."
		var previous := save_path
		select_slot(slot)
		var ok := write_save(data)
		save_path=previous
		if ok:
			mark_used(slot)
			index.load(SLOT_INDEX)
			index.set_value("slots","legacy_migrated",true)
			index.save(SLOT_INDEX)
			return "Previous progress copied to Slot %d; the original save and migration backup are preserved."%slot
		# The immutable backup is also an explicit recovery source if migration fails.
		return "Migration could not write a slot. Original progress and backup are preserved."
	return "All three slots are occupied. The previous single-save file was preserved."
