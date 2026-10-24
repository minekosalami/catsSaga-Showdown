extends SceneTree
const Progress=preload("res://scripts/rpg/progress.gd")
const Score=preload("res://scripts/rpg/score.gd")
const Records=preload("res://scripts/rpg/records.gd")
var checks := 0
var failures := 0
class TestPlayer extends Node:
	signal health_changed(value: int)
	var health := 20
	var shield_remaining := 0.0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":quit(1);return
	run.call_deferred()
func run() -> void:
	var progress := Progress.new()
	check(progress.level()==1 and progress.max_hp()==20 and progress.attack()==1.0,"LV1 defaults")
	for lv in range(1,21):
		progress.total_exp=Progress.threshold(lv)
		check(progress.level()==lv and progress.max_hp()==20+roundi(80.0*(lv-1)/19),"HP formula LV%d"%lv)
		check(is_equal_approx(progress.attack(),1.0+.05*(lv-1)),"fractional attack LV%d"%lv)
		if lv>1:check(Progress.threshold(lv)-Progress.threshold(lv-1)>Progress.threshold(lv-1)-Progress.threshold(maxi(1,lv-2)),"progressive EXP")
	progress.restore({})
	check(progress.award("bart").exp==100 and progress.level()==2,"boss reward and leveling")
	check(progress.award("bart").exp==0 and progress.total_exp==100,"no repeat boss EXP")
	progress.restore({});progress.total_exp=9400;progress.award("boss2")
	check(progress.level()==20 and progress.max_hp()==100 and progress.total_exp==9500,"cap level and EXP")
	for i in 10:progress.award("ordinary",true)
	check(progress.level()==20 and progress.total_exp==9500,"cap remains stable")
	progress.restore({});var multi: Dictionary=progress.award("boss2")
	check(multi.level==3 and multi.level_before==1,"multiple levels from one reward")
	check(not Progress.validate({"total_exp":-1}).size() and Progress.validate({}).inventory.first_aid==0,"legacy defaults and invalid EXP")
	check(Progress.validate({"inventory":{"shield_ring":1.5}}).is_empty(),"reject fractional item quantity")
	var wallet := preload("res://scripts/story/progress.gd").new()
	wallet.necoins=100
	progress.restore({})
	for id in Progress.ITEMS:
		check(progress.purchase(id,wallet),"purchase "+id)
	check(wallet.necoins==0 and progress.inventory=={"first_aid":1,"cat_treats":1,"shield_ring":1},"correct prices and counts")
	check(not progress.purchase("first_aid",wallet) and wallet.necoins==0,"insufficient funds safe")
	var restored := Progress.new();restored.restore(progress.snapshot())
	check(restored.inventory==progress.inventory,"inventory roundtrip")
	var player := TestPlayer.new()
	check(not progress.use_item("cat_treats",player) and progress.inventory.cat_treats==1,"no healing waste")
	player.health=1
	check(progress.use_item("cat_treats",player) and player.health==8 and progress.inventory.cat_treats==0,"33 percent nearest rounding")
	check(not progress.use_item("cat_treats",player),"zero quantity cannot use")
	check(progress.use_item("first_aid",player) and player.health==20,"full heal")
	progress.inventory.shield_ring=2
	check(progress.use_item("shield_ring",player) and player.shield_remaining==5,"shield duration")
	player.shield_remaining=3
	check(progress.use_item("shield_ring",player) and player.shield_remaining==5 and progress.inventory.shield_ring==0,"shield refresh no stack")
	progress.total_exp=9500;progress.inventory.cat_treats=2;player.health=90
	progress.use_item("cat_treats",player)
	check(player.health==100,"healing caps at level20 max")
	player.free()
	var perfect := Score.new();perfect.advance(.05)
	check(perfect.percent()==100 and Score.grade(perfect.percent())=="S+","early perfect and explicit S+")
	var clustered := Score.new();clustered.advance(1);clustered.damage();clustered.advance(1);clustered.damage();clustered.advance(8)
	var spread := Score.new();spread.advance(3);spread.damage();spread.advance(3);spread.damage();spread.advance(4)
	check(is_equal_approx(clustered.percent(),66) and is_equal_approx(spread.percent(),34),"squared streak formula")
	check(clustered.percent()>spread.percent(),"clustered hits less costly than spread")
	check(Score.new().percent()==100,"zero-time no-hit safe")
	var zero := Score.new();zero.damage();check(zero.percent()==0,"zero-time damaged safe")
	for pair in [[100.0,"S+"],[99.9999,"A+"],[90.0,"A+"],[89.999,"A"],[80.0,"A"],[70.0,"B"],[60.0,"C"],[40.0,"D"],[39.999,"F"]]:
		check(Score.grade(pair[0])==pair[1],"unrounded grade boundary")
	check(Score.display(99.9999)=="99.99%","nonperfect display never 100")
	var records := Records.new();records.best={}
	check(records.improve("ordinary_0",88.125) and not records.improve("ordinary_0",88) and not records.improve("ordinary_0",88.125),"only strictly better PB")
	check(records.improve("bart",100) and records.best.size()==2,"separate enemy records")
	check(not records.improve("bad",NAN),"reject corrupt score")
	check(records.improve("fractional",66.12345678901234),"arbitrary unrounded score accepted")
	check(records.persist(),"atomic record write")
	var disk := Records.new();disk.load_records();check(disk.best==records.best,"record disk reload")
	var session: Node=root.get_node("Session")
	var legacy: Dictionary=session.snapshot("entrance",Vector2(240,912))
	legacy.erase("rpg")
	var migrated: Dictionary=session.saves.validate(legacy)
	check(not migrated.is_empty() and migrated.rpg.total_exp==0 and migrated.rpg.inventory.shield_ring==0,"legacy full save gains RPG defaults")
	legacy.rpg={"inventory":{"cat_treats":-1}}
	check(session.saves.validate(legacy).is_empty(),"malformed RPG full save rejected")
	print("RPG FOUNDATION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
