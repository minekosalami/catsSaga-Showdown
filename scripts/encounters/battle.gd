extends "res://scripts/main.gd"
## Ordinary controller reuses the Showdown player/projectiles and host. No boss
## script, cue schedule, music assignment or boss invulnerability is changed.
const Catalog=preload("res://scripts/encounters/catalog.gd")
var kind =0
var duration =0.0
var fled =false
var settled =false
var flee_cooldown =0.0
var rng =RandomNumberGenerator.new()
func _ready() -> void:
	kind=Session.forest_encounters.active.get("kind",0)
	rng.randomize()
	_find_scene_nodes()
	ui=$UI
	boss=preload("res://scripts/encounters/enemy.gd").new()
	boss.kind=kind;boss.battle=self
	boss.position=Vector2(270,200)
	add_child(boss)
	player.position=Vector2(270,780)
	player.game_over.connect(_on_game_over)
	music_player.stream=music_player.stream.duplicate()
	music_player.stream.loop=false
	duration=music_player.stream.get_length()
	music_player.finished.connect(_deadline)
	ui.refresh()
	if not Session.battle_entry_pending:music_player.play(0)
func _draw() -> void:
	draw_rect(Rect2(8,8,524,884),Color("#64766e"),false,1)
	for y in range(130,840,64):draw_line(Vector2(14,y),Vector2(526,y),Color(.3,.45,.4,.07),1)
func _process(delta: float) -> void:
	if settled:return
	elapsed_time=music_player.get_playback_position()
	flee_cooldown=maxf(0,flee_cooldown-delta)
	ui.refresh()
	if elapsed_time>=duration:_deadline()
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V:
		attempt_flee()
		get_viewport().set_input_as_handled()
func projectile_count() -> int:
	var count =0
	for node in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_ancestor_of(node) and not node.is_queued_for_deletion():count+=1
	return count
func attempt_flee() -> void:
	if settled or get_tree().paused or flee_cooldown>0 or Session.busy:return
	flee_cooldown=1.0
	if rng.randi_range(0,Catalog.FLEE_OUTCOMES-1)==0:finish("flee")
	else:ui.status.text="FLEE — FAILED"
func _deadline() -> void:
	if not settled:finish("defeat")
func _on_game_over() -> void:
	# The inherited player pauses after emitting this signal. Session ALWAYS
	# handles the deferred return and clears that pause without rolling back saves.
	finish("defeat")
func finish(result: String) -> void:
	if settled:return
	# Audio deadline wins a same-frame race: no victory at/after the endpoint.
	if result=="victory" and (not music_player.playing or music_player.get_playback_position()>=duration):result="defeat"
	settled=true
	game_over=result=="defeat"
	victory_started=result!="defeat"
	player.set_process(false);player.set_physics_process(false);player.set_process_input(false)
	for node in get_children():
		if node.is_in_group("enemy_bullets"):
			node.set_deferred("monitoring",false);node.queue_free()
	if music_player.playing:
		create_tween().tween_property(music_player,"volume_db",-60.0,.18)
	if result=="victory": get_tree().current_scene.rpg_ui.complete()
	else: Session.forest_encounters.resolve.call_deferred(result)
