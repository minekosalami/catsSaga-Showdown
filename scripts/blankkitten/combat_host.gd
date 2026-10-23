extends "res://scripts/systems/combat_host.gd"

func record_victory() -> void:
	if battle.practice_mode or battle.development_run: return
	if Session.encounter_active and Session.encounter_id == "blankkitten":
		Session.story_flags["blankkitten_defeated"] = true
		Session.save_boss_victory()

func return_to_forest() -> void:
	Session.return_from_blankkitten()

func retry() -> void:
	if battle.game_over and Session.encounter_active:Session.retry_last_save()
	else:Session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)

func finish_entry() -> void:
	if battle.game_over:
		Session.restore_suspended_modes()
		battle.process_mode = Node.PROCESS_MODE_PAUSABLE
		return
	super.finish_entry()
	battle.state = battle.State.INTRODUCTION
	battle.apply_launch()

func practice(index: int) -> void:
	var seen: Dictionary = Session.get_meta("blankkitten_seen_stages",{})
	if not seen.has(index): return
	Session.set_meta("blankkitten_launch",{"time":battle.Cue.STARTS[index],"practice":true})
	Session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
