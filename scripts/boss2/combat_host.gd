extends "res://scripts/systems/combat_host.gd"
func record_victory() -> void:
	if Session.encounter_active and Session.encounter_id == "boss2":
		if not Session.story_flags.get("boss2_defeated", false):
			Session.story_flags["boss2_victory_dialogue_pending"] = true
		Session.story_flags["boss2_defeated"] = true
		rpg_ui.complete()
		Session.save_boss_victory()
func return_to_forest() -> void:
	Session.return_to_flooded_forest()
func retry() -> void:
	if battle.game_over and Session.encounter_active:Session.retry_last_save()
	else:Session.transition_to("res://scenes/boss2/combat_host.tscn",true)
