extends SceneTree
const Progress = preload("res://scripts/story/progress.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		push_error(message)
		quit(1)
		assert(value,message)
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(1)
		return
	run.call_deferred()
func run() -> void:
	var p := Progress.new()
	check(p.necoins==0,"zero initial currency")
	check(not p.acquire_wand(true),"insufficient funds")
	check(p.acquire_wand(false),"steal without payment")
	check(not p.acquire_wand(false) and not p.acquire_wand(true),"no duplicate acquisition")
	check(not p.reward_cupid(false),"cannot reward unaccepted quest")
	p.accept_cupid()
	check(p.reward_cupid(false) and p.necoins==50,"50 reward")
	check(not p.reward_cupid(true) and p.necoins==50,"no second reward")
	check(not p.wand_owned and p.wand_acquired,"return consumes ownership not acquisition history")
	check(not p.acquire_wand(false),"cannot steal returned wand")
	var restored := Progress.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(p.snapshot()))),"JSON round trip")
	check(restored.snapshot()==p.snapshot(),"all fields round trip")
	p=Progress.new()
	p.accept_cupid()
	p.acquire_wand(false)
	check(p.reward_cupid(true) and p.necoins==75,"75 reward branch")
	p=Progress.new()
	p.necoins=9999 # Test fixture only: no gameplay income source.
	check(p.acquire_wand(true) and p.necoins==0,"exact purchase deduction")
	for id in Progress.FEATHER_IDS:
		check(p.collect_feather(id),"unique feather "+id)
		check(not p.collect_feather(id),"duplicate blocked "+id)
		check(p.cat_toy==(p.feathers.size()==10),"toy only at ten")
	check(not p.collect_feather("invented"),"unknown feather rejected")
	check(Progress.validate({"necoins":-1}).is_empty(),"negative currency rejected")
	check(Progress.validate({"necoins":1.5}).is_empty(),"fractional currency rejected")
	check(Progress.validate({"cat_toy":true}).is_empty(),"inconsistent toy rejected")
	var session := root.get_node("Session")
	session.story_progress.restore(p.snapshot())
	var snapshot: Dictionary=session.snapshot("entrance",Vector2(240,912))
	check(not snapshot.is_empty() and snapshot.story_progress==p.snapshot(),"real save validator preserves progress")
	var filename := "user://story-progress-test.json"
	var file := FileAccess.open(filename,FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	var loaded: Dictionary=session.saves.read_file(filename)
	check(loaded.story_progress==p.snapshot(),"real disk save/read validation")
	snapshot.erase("story_progress")
	var legacy: Dictionary=session.saves.validate(snapshot)
	check(legacy.story_progress==Progress.new().snapshot(),"legacy saves default safely")
	for name in ["butterscotch","cupid_request","cupid_return"]:
		var graph: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/"+name+".json"))
		check(graph.nodes.has(graph.start),"dialogue start exists")
		for node in graph.nodes.values():
			check(not node.lines.is_empty(),"dialogue node has supplied lines")
			for choice in node.get("choices",[]):
				check(choice.has("end") or graph.nodes.has(choice.get("next","")),"choice destination exists")
	print("PASS: %d story progress checks"%checks)
	quit()
