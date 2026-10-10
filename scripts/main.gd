
extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")

@export var enemy_spawn_interval: float = 1.5
@export var enemy_spawn_margin: float = 40.0

# Screen shake
var shake_time: float = 0.0
var shake_strength: float = 0.0
var original_position: Vector2

# Gameplay state
var game_over: bool = false
var boss_spawned: bool = false
var elapsed_time: float = 0.0
var enemy_spawn_timer: float = 0.0

# Existing UI references
var ui: Node
var health_label: Label
var time_label: Label
var game_over_label: Label
var restart_button: Button

# Scene references
var player: Area2D
var boss: Node2D
var music_player: AudioStreamPlayer


func _ready() -> void:
	original_position = position

	_find_scene_nodes()
	_find_existing_ui()
	_connect_player_signals()
	_connect_restart_button()

	if music_player != null:
		music_player.play()


func _find_scene_nodes() -> void:
	player = get_node_or_null("Player") as Area2D

	if player == null:
		push_warning("main.gd: Player node not found.")

	music_player = _find_audio_player(self)


func _find_audio_player(node: Node) -> AudioStreamPlayer:
	for child in node.get_children():
		if child is AudioStreamPlayer:
			return child as AudioStreamPlayer

		var found := _find_audio_player(child)
		if found != null:
			return found

	return null


func _find_existing_ui() -> void:
	ui = get_node_or_null("UI")

	if ui == null:
		push_warning("main.gd: UI node not found.")
		return

	health_label = _find_label_by_names(
		ui, ["HealthLabel", "Health", "HealthText"]
	)

	time_label = _find_label_by_names(
		ui, ["TimeLabel", "TimerLabel", "Time", "Timer"]
	)

	game_over_label = _find_label_by_names(
		ui, ["GameOverLabel", "GameOverText", "GameOver"]
	)

	restart_button = _find_button_by_names(
		ui, ["RestartButton", "RestartBtn", "Restart"]
	)

	if game_over_label != null:
		game_over_label.visible = false

	if restart_button != null:
		restart_button.visible = false


func _find_label_by_names(root: Node, names: Array) -> Label:
	for node_name in names:
		var found := root.find_child(node_name, true, false)
		if found is Label:
			return found as Label

	return null


func _find_button_by_names(root: Node, names: Array) -> Button:
	for node_name in names:
		var found := root.find_child(node_name, true, false)
		if found is Button:
			return found as Button

	return null


func _connect_player_signals() -> void:
	if player == null:
		return

	if player.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_health_changed")
		if not player.is_connected("health_changed", health_callable):
			player.connect("health_changed", health_callable)

	if player.has_signal("game_over"):
		var game_over_callable := Callable(self, "_on_game_over")
		if not player.is_connected("game_over", game_over_callable):
			player.connect("game_over", game_over_callable)


func _connect_restart_button() -> void:
	if restart_button == null:
		push_warning(
			"main.gd: Restart button not found. Check its node name."
		)
		return

	var restart_callable := Callable(self, "_on_restart_pressed")
	if not restart_button.pressed.is_connected(restart_callable):
		restart_button.pressed.connect(restart_callable)


func _process(delta: float) -> void:
	if game_over:
		return

	elapsed_time += delta

	# Sync the timer with the music when it is playing.
	if music_player != null and music_player.playing:
		elapsed_time = music_player.get_playback_position()

	if time_label != null:
		var total_seconds := int(elapsed_time)
		var minutes := total_seconds / 60
		var seconds := total_seconds % 60
		time_label.text = "Time: %d:%02d" % [minutes, seconds]

	_update_screen_shake(delta)
	_spawn_enemies(delta)
	_update_boss()


func _spawn_enemies(delta: float) -> void:
	if game_over or boss_spawned or enemy_scene == null:
		return

	enemy_spawn_timer -= delta

	if enemy_spawn_timer > 0.0:
		return

	enemy_spawn_timer = enemy_spawn_interval

	var enemy := enemy_scene.instantiate()
	add_child(enemy)

	var screen_size := get_viewport_rect().size
	var min_x := minf(enemy_spawn_margin, screen_size.x * 0.5)
	var max_x := maxf(min_x, screen_size.x - enemy_spawn_margin)
	var spawn_x := randf_range(min_x, max_x)

	enemy.global_position = Vector2(spawn_x, -30.0)


func _update_boss() -> void:
	# Keep an existing boss on the same playback clock as the main scene.
	if is_instance_valid(boss) and "elapsed" in boss:
		boss.elapsed = elapsed_time

	if game_over or boss_spawned or elapsed_time < 6.85:
		return

	if boss_scene == null:
		push_warning("main.gd: Boss scene is missing.")
		return

	boss = boss_scene.instantiate()
	add_child(boss)
	boss_spawned = true

	if "elapsed" in boss:
		boss.elapsed = elapsed_time

	print("Boss spawned!")


func _update_screen_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)

		var offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		position = original_position + offset
	else:
		position = original_position
		shake_strength = 0.0


func _on_health_changed(new_health: int) -> void:
	if health_label != null:
		health_label.text = "Health: %d" % new_health


func _on_game_over() -> void:
	if game_over:
		return

	game_over = true

	if game_over_label != null:
		game_over_label.text = "GAME OVER"
		game_over_label.visible = true

	if restart_button != null:
		restart_button.visible = true

	print("Game over.")


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
