extends RefCounted
## Slot-scoped earned progression. HP and attack are derived, never independent
## save fields that can disagree with EXP after a legacy-save migration.
signal changed
const MAX_LEVEL := 20
const ITEMS := {
	"first_aid": {"name":"First Aid Kit", "price":50, "effect":"Restore all HP"},
	"cat_treats": {"name":"Cat Treats", "price":20, "effect":"Restore 33% HP"},
	"shield_ring": {"name":"Shield Ring", "price":30, "effect":"Block damage for 5s"}}
const REWARDS := {"ordinary":25, "bart":100, "blankkitten":150, "boss2":200}
var total_exp := 0
var inventory := {"first_aid":0, "cat_treats":0, "shield_ring":0}
var rewarded_bosses: Array[String] = []

static func threshold(lv: int) -> int:
	return roundi(25.0 * (lv - 1) * (lv - 1) + 25.0 * (lv - 1))
func level() -> int:
	var lv := 1
	while lv < MAX_LEVEL and total_exp >= threshold(lv + 1): lv += 1
	return lv
func max_hp() -> int:
	return 20 + roundi(80.0 * (level() - 1) / 19.0)
func attack() -> float:
	return 1.0 + 0.05 * (level() - 1)
func snapshot() -> Dictionary:
	return {"total_exp":total_exp, "inventory":inventory.duplicate(), "rewarded_bosses":rewarded_bosses.duplicate()}
static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var exp_value: Variant = value.get("total_exp",0)
	if not whole(exp_value,9500): return {}
	var counts: Variant = value.get("inventory",{})
	var bosses: Variant = value.get("rewarded_bosses",[])
	if not counts is Dictionary or not bosses is Array: return {}
	var clean := {"total_exp":int(exp_value), "inventory":{}, "rewarded_bosses":[]}
	for id in ITEMS:
		if not whole(counts.get(id,0),1000000): return {}
		clean.inventory[id] = int(counts.get(id,0))
	for id in bosses:
		if not id is String or id.is_empty() or id.length()>80 or id in clean.rewarded_bosses: return {}
		clean.rewarded_bosses.append(id)
	return clean
static func whole(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floor(float(value))
func restore(value: Dictionary) -> bool:
	var clean := validate(value)
	if clean.is_empty(): return false
	total_exp=clean.total_exp
	inventory=clean.inventory
	rewarded_bosses.assign(clean.rewarded_bosses)
	return true
func award(id: String, ordinary := false) -> Dictionary:
	var before := level()
	var reward := int(REWARDS.get("ordinary" if ordinary else id,100))
	if not ordinary:
		if id in rewarded_bosses: reward=0
		else: rewarded_bosses.append(id)
	total_exp=mini(threshold(MAX_LEVEL),total_exp+reward)
	changed.emit()
	return {"exp":reward,"level_before":before,"level":level(),"max_hp":max_hp()}
func purchase(id: String, wallet: RefCounted) -> bool:
	if not ITEMS.has(id) or inventory[id]>=1000000 or wallet.necoins<ITEMS[id].price: return false
	wallet.necoins-=ITEMS[id].price
	inventory[id]+=1
	# Both changes are complete before either persistence listener runs.
	wallet.changed.emit()
	changed.emit()
	return true
func use_item(id: String, player: Node) -> bool:
	if not ITEMS.has(id) or inventory[id]<=0 or player.health<=0: return false
	if id!="shield_ring" and player.health>=max_hp(): return false
	if id=="shield_ring": player.shield_remaining=5.0
	else:
		var healing := max_hp() if id=="first_aid" else maxi(1,roundi(max_hp()*0.33))
		player.health=mini(max_hp(),player.health+healing)
		if player.has_signal("health_changed"): player.health_changed.emit(player.health)
	inventory[id]-=1
	changed.emit()
	return true
