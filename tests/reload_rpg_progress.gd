extends SceneTree
## Run in a NEW process with headless_rpg_battles.gd's isolated profile.
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1":quit(1);return
	run.call_deferred()
func run() -> void:
	var session: Node=root.get_node("Session")
	var data: Dictionary=session.saves.read_slot(3)
	var ok: bool = not data.is_empty() and data.rpg.total_exp==150 and data.story_progress.cupid_accepted and data.story_progress.wand_acquired and "entrance_white" in data.story_progress.feathers
	ok=ok and session.records.best.has_all(["ordinary_4","bart","boss2","blankkitten"])
	if ok:ok=await session.load_game(3)
	ok=ok and session.rpg.level()==3 and session.rpg.max_hp()==28 and session.rpg.inventory.first_aid==0 and session.story_flags.get("blankkitten_defeated",false)
	print("RPG NEW-PROCESS RELOAD: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
