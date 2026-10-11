extends "res://scripts/systems/combat_host.gd"

func record_victory() -> void:
	if Session.encounter_active and Session.encounter_id == "blankkitten":
		Session.story_flags["blankkitten_defeated"] = true
		Session.save_boss_victory()

func return_to_forest() -> void:
	Session.return_from_blankkitten()

func retry() -> void:
	Session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)

func finish_entry() -> void:
	if battle.game_over:
		battle.process_mode = Node.PROCESS_MODE_PAUSABLE
		Session.restore_suspended_modes()
		return
	super.finish_entry()
	battle.state = battle.State.INTRODUCTION
