extends "res://scripts/systems/combat_host.gd"
const Cfg = preload("res://scripts/incarna/config.gd")

func record_victory() -> void:
	if Session.encounter_active and Session.encounter_id == "incarna" and battle.victory_started and not battle.game_over and battle.elapsed_time >= Cfg.END and battle.player.health > 0:
		Session.story_flags["incarna_defeated"] = true
		rpg_ui.complete()
		Session.save_boss_victory()

func return_to_forest() -> void:
	if battle.victory_started: Session.return_to_cave()

func retry() -> void:
	if battle.game_over: Session.retry_last_save()
	else: Session.transition_to("res://scenes/incarna/combat_host.tscn",true)
