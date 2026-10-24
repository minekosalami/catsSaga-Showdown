extends "res://scenes/player.gd"
# All movement, shooting, HP, cheats and SATURATE remain inherited.
func take_damage(amount: int) -> void:
	var can_hit = not invincible and shield_remaining<=0 and invulnerability_timer<=0 and health>0
	super.take_damage(amount)
	if can_hit and health>0:
		invulnerability_timer=preload("res://scripts/encounters/catalog.gd").HIT_INVULNERABILITY
