extends "res://tests/headless_battle_entry.gd"
## The original entry probe, restricted to the three currently playable bosses.
## Source sequence, sounds, timings, camera conversion and freeze checks are reused.
func _initialize() -> void:
	output = OS.get_temp_dir().path_join("catsSaga-protected-entry-review")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output = argument.trim_prefix("--output=")
	super._initialize()
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://protected-entry-polish.json"
	for encounter in [["res://scenes/combat_host.tscn","bart",true],["res://scenes/boss2/combat_host.tscn","boss2",true],["res://scenes/blankkitten/combat_host.tscn","blankkitten",true],["res://scenes/blankkitten/combat_host.tscn","blankkitten",false]]:
		var history: Array[String] = []
		var record := func(value: String):history.append(value)
		session.battle_transition.stage_changed.connect(record)
		await probe(encounter[0],encounter[1],encounter[2])
		session.battle_transition.stage_changed.disconnect(record)
		check(history.slice(history.find("freeze"))==["freeze","blackout","cat_flash","loading","travel","star_flash","cat_return","reveal","idle"],"protected animation stage order remains exact")
	check(not await session.transition_to("res://scenes/incarna/combat_host.tscn",true),"inactive Incarna remains blocked")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	print("PROTECTED ENTRY: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
