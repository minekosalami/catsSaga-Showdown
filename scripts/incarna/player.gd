extends "res://scripts/boss2/player.gd"
const Cfg = preload("res://scripts/incarna/config.gd")
var entrance_locked := true

func _input(event: InputEvent) -> void:
	if entrance_locked: return
	super._input(event)

func _physics_process(delta: float) -> void:
	if entrance_locked:
		velocity = Vector2.ZERO
		previous_hit_center = hit_center()
		return
	super._physics_process(delta)
	# Clamp the actual damage center, including the existing artwork offset.
	var bounded := Cfg.PLAY_AREA.grow(-damage_hitbox_radius)
	var corrected: Vector2 = hit_center().clamp(bounded.position,bounded.end)
	position += corrected-hit_center()

func take_damage(amount: int) -> void:
	if entrance_locked: return
	super.take_damage(amount)
