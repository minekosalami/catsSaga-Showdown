extends RefCounted

const CODES := ["CATA", "BEAM", "thefogisleaving", "mycoordinates", "anywhereiwant", "hitbox"]
const LABELS := {"CATA":"CATA", "BEAM":"BEAM", "thefogisleaving":"thefogisleaving", "mycoordinates":"mycoordinates", "anywhereiwant":"anywhereiwant", "hitbox":"Hitbox debug · F3"}
const DESCRIPTIONS := {"CATA":"Invincibility for the current combat player.", "BEAM":"Unlimited SATURATE. Survival fights still disable attacks.", "thefogisleaving":"Reveal the current map without saving revealed terrain.", "mycoordinates":"Display the overworld player's global X and Y.", "anywhereiwant":"Bypass region locks for this play session.", "hitbox":"Show the combat hitbox (debug builds only)."}

func context() -> Dictionary:
	var scene := Session.get_tree().current_scene
	var world: Node = scene if scene != null and scene.name == "Overworld" else null
	var battle: Node = scene.battle if scene != null and scene.has_method("record_victory") else null
	var player: Node = battle.player if battle != null else (world.player if world != null else null)
	return {"scene":scene,"world":world,"battle":battle,"player":player}

func state(code: String) -> Dictionary:
	var target := context()
	var player: Node = target.player
	var world_ready: bool = target.world != null and not target.world.checking_spawn and not target.world.dialogue.active and not target.world.awaiting_victory_dialogue
	var available := false
	var active := false
	match code:
		"CATA":
			available = player != null and player.has_method("toggle_invincibility")
			active = player.invincible if available else false
		"BEAM":
			available = player != null and player.has_method("toggle_unlimited_saturate")
			active = player.unlimited_saturate if available else false
		"hitbox":
			available = OS.is_debug_build() and player != null and player.has_method("toggle_debug_hitbox")
			active = player.debug_hitbox_enabled if available else false
		"thefogisleaving":
			available = world_ready
			active = Session.map_reveal_cheat
		"mycoordinates": available = world_ready
		"anywhereiwant":
			available = world_ready
			active = Session.unrestricted_region_access
		_:
			if code.begins_with("seek:"):
				available = OS.is_debug_build() and target.battle != null and target.battle.has_method("seek_timestamp") and not target.battle.game_over and not target.battle.victory_started
	return {"available":available and not Session.busy,"active":active}

func activate(code: String) -> String:
	if not state(code).available: return "Unavailable in this scene."
	var target := context()
	var message := ""
	match code:
		"CATA": target.player.toggle_invincibility()
		"BEAM": target.player.toggle_unlimited_saturate()
		"hitbox": target.player.toggle_debug_hitbox()
		"thefogisleaving": Session.map_reveal_cheat = not Session.map_reveal_cheat
		"mycoordinates":
			var point: Vector2 = target.player.global_position
			message = "X: %s | Y: %s" % [str(point.x),str(point.y)]
		"anywhereiwant":
			Session.unrestricted_region_access = not Session.unrestricted_region_access
			message = "Unrestricted region access: " + ("enabled" if Session.unrestricted_region_access else "disabled")
		_:
			if code.begins_with("seek:"):
				var index := code.trim_prefix("seek:").to_int()
				if index < 0 or index >= target.battle.Cue.STARTS.size(): return "Invalid stage."
				return seek(target.battle.Cue.STARTS[index])
	if not message.is_empty(): Session.show_notification(message)
	return message if not message.is_empty() else LABELS[code] + ": " + ("ON" if state(code).active else "OFF")

func seek(time: float) -> String:
	if not state("seek:0").available: return "Seek unavailable."
	var battle: Node = context().battle
	if not battle.seek_timestamp(time): return "Seek unavailable."
	return "Preview: " + battle.Cue.NAMES[battle.Cue.stage_at(time)]
