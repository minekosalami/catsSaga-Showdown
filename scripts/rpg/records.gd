extends RefCounted
const PATH := "user://showdown-records.json"
const NAMES := {"ordinary_0":"Purrrresents!","ordinary_1":"FireKittens","ordinary_2":"TopCat","ordinary_3":"Sharpurr","ordinary_4":"BiNarty","ordinary_5":"Toasters","ordinary_6":"2kMEOWpH","ordinary_7":"Sir Swirlur","bart":"Smoki","blankkitten":"BlankKitten","boss2":"Doppelcat"}
var best: Dictionary = {}
func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return {}
	for id in data:
		var value: Variant=data[id]
		if not id is String or id.length()>80 or not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>100: return {}
	return data
func load_records() -> void:
	best=read(PATH)
	if best.is_empty(): best=read(PATH+".bak")
func improve(id: String, score: float) -> bool:
	if not is_finite(score) or score<0 or score>100 or score<=float(best.get(id,-1)): return false
	best[id]=score
	return true
func persist() -> bool:
	var file := FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(best,"\t",true,true));file.flush();file.close()
	if read(PATH+".tmp")!=best: return false
	if FileAccess.file_exists(PATH) and not read(PATH).is_empty():
		if DirAccess.copy_absolute(PATH,PATH+".bak")!=OK: return false
	return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK
