extends RefCounted
## Manual-save story data. No rewards are granted by loading or HUD rendering.
signal changed
const FEATHER_IDS := ["entrance_white", "entrance_brown", "deep_blue", "deep_purple", "deep_orange", "fluffy_pink", "fluffy_green", "flooded_red", "flooded_yellow", "flooded_cyan"]
const WAND_PRICE := 9999
var necoins := 0
var cupid_accepted := false
var wand_acquired := false # Remains true after returning it; prevents reacquisition.
var wand_owned := false
var cupid_completed := false
var cupid_rewarded := false
var feathers: Array[String] = []
var cat_toy := false

func snapshot() -> Dictionary:
	return {"necoins":necoins, "cupid_accepted":cupid_accepted, "wand_acquired":wand_acquired, "wand_owned":wand_owned, "cupid_completed":cupid_completed, "cupid_rewarded":cupid_rewarded, "feathers":feathers.duplicate(), "cat_toy":cat_toy}

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var clean := {"necoins":0, "cupid_accepted":false, "wand_acquired":false, "wand_owned":false, "cupid_completed":false, "cupid_rewarded":false, "feathers":[], "cat_toy":false}
	var coins: Variant = value.get("necoins",0)
	if not (coins is int or coins is float) or not is_finite(float(coins)) or coins < 0 or coins > 2147483647 or float(coins) != floor(float(coins)): return {}
	clean.necoins = int(coins)
	for key in ["cupid_accepted","wand_acquired","wand_owned","cupid_completed","cupid_rewarded","cat_toy"]:
		if not value.get(key,false) is bool: return {}
		clean[key] = value.get(key,false)
	var collected: Variant = value.get("feathers",[])
	if not collected is Array: return {}
	for id in collected:
		if not id is String or id not in FEATHER_IDS or id in clean.feathers: return {}
		clean.feathers.append(id)
	if clean.wand_owned and not clean.wand_acquired: return {}
	if clean.cupid_completed != clean.cupid_rewarded: return {}
	if clean.cupid_completed and (not clean.cupid_accepted or not clean.wand_acquired or clean.wand_owned): return {}
	if clean.cat_toy != (clean.feathers.size()==10): return {}
	return clean

func restore(value: Dictionary) -> bool:
	var clean := validate(value)
	if clean.is_empty(): return false
	for key in clean:
		if key=="feathers": feathers.assign(clean[key])
		else: set(key,clean[key])
	changed.emit()
	return true

func accept_cupid() -> void:
	if cupid_completed: return
	cupid_accepted = true
	changed.emit()

func acquire_wand(purchase: bool) -> bool:
	if wand_acquired or (purchase and necoins<WAND_PRICE): return false
	if purchase: necoins-=WAND_PRICE
	wand_acquired=true
	wand_owned=true
	changed.emit()
	return true

func reward_cupid(declined_reward: bool) -> bool:
	if not cupid_accepted or not wand_owned or cupid_completed or cupid_rewarded: return false
	wand_owned=false
	cupid_completed=true
	cupid_rewarded=true
	necoins+=75 if declined_reward else 50
	changed.emit()
	return true

func collect_feather(id: String) -> bool:
	if id not in FEATHER_IDS or id in feathers: return false
	feathers.append(id)
	if feathers.size()==10: cat_toy=true
	changed.emit()
	return true
