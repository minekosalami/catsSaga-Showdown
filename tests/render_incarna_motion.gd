extends SceneTree
## Built-in movie capture: sample authored animation at real 60 Hz, not jump cuts.
var game: Node
var age := 0.0
func _initialize() -> void:
	root.size = Vector2i(1280,720)
	call_deferred("start")
func start() -> void:
	root.get_node("Session").saves.save_path = "user://validation-incarna-motion.json"
	await root.get_node("Session").transition_to("res://scenes/incarna/combat_host.tscn",true)
	game = current_scene.battle
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.timeline.set_physics_process(false)
	game.music_player.stop()
func _process(delta: float) -> bool:
	if game == null: return false
	age += delta
	var clock := age
	if age >= 10 and age < 14:
		clock = 41.14+age-10
		if age-delta < 10:
			game.timeline.reset_clock(41.14)
			game.timeline.issue({"time":41.14,"kind":"paw","section":3,"index":0})
			game.timeline.issue({"time":41.14,"kind":"zone","section":3,"index":0})
	elif age >= 14:
		clock = 82.28+age-14
		if age-delta < 14: game.timeline.reset_clock(82.28)
		game.player.position.x = 420+(age-14)*100
	game.update_clock(clock)
	if age >= 18: quit(0)
	return false
