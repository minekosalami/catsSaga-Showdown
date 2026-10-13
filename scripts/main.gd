
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
var victory_started: bool = false
var victory_navigation: bool = false
var victory_music_tween: Tween
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
var presentation: Node2D
var music_player: AudioStreamPlayer


func _ready() -> void:
	original_position = position

	presentation = $BattlePresentation
	_find_scene_nodes()
	if player != null:
		player.position = Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y - 120.0)
	_find_existing_ui()
	_connect_player_signals()
	_connect_restart_button()

	if music_player != null and not Session.battle_entry_pending:
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
	if game_over or victory_started:
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
	_update_boss()
	presentation.update_clock(elapsed_time)
	_spawn_enemies(delta)


func _spawn_enemies(delta: float) -> void:
	if game_over or victory_started or boss_spawned or enemy_scene == null:
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

	if game_over or victory_started or boss_spawned or elapsed_time < 6.85:
		return

	if boss_scene == null:
		push_warning("main.gd: Boss scene is missing.")
		return

	# Free only opening enemies synchronously, before the boss joins "enemies".
	for opening_enemy in get_tree().get_nodes_in_group("opening_enemies"):
		opening_enemy.free()
	boss = boss_scene.instantiate()
	# Leave clear space below the top HUD for the full boss sprite.
	boss.defeated.connect(_on_boss_defeated)
	boss.defeat_finished.connect(_on_boss_defeat_finished)
	boss.position = Vector2(get_viewport_rect().size.x * 0.5, 240.0)
	add_child(boss)
	boss_spawned = true

	if "elapsed" in boss:
		boss.elapsed = elapsed_time

	boss.play_entrance()
	if ui != null and ui.has_method("show_boss_entrance"):
		ui.show_boss_entrance()
	print("Boss spawned!")


func _update_screen_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)

		var offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		presentation.apply_shake(offset)
	else:
		presentation.apply_shake(Vector2.ZERO)
		shake_strength = 0.0


func _on_health_changed(new_health: int) -> void:
	if health_label != null:
		health_label.text = "Health: %d" % new_health


func _on_game_over() -> void:
	if game_over or victory_started:
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
	var host := get_tree().current_scene
	if host.has_method("retry"):
		host.retry()
	else:
		get_tree().reload_current_scene()

func _on_boss_defeated() -> void:
	if victory_started or game_over or not is_instance_valid(boss) or boss.health > 0:
		return
	victory_started = true
	position = original_position
	shake_time = 0.0
	# Disable input/movement without pausing the defeat tween or audio mixer.
	player.get_node("HitboxDebug").hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_deferred("monitoring", false)
	player.set_deferred("monitorable", false)
	for projectile in get_tree().get_nodes_in_group("enemy_bullets"):
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		projectile.set_deferred("monitoring", false)
		projectile.queue_free()
	if music_player != null:
		victory_music_tween = create_tween()
		victory_music_tween.tween_property(music_player, "volume_db", -60.0, 1.2)
		victory_music_tween.tween_callback(music_player.stop)

func _on_boss_defeat_finished() -> void:
	if victory_started:
		var host := get_tree().current_scene
		if host.has_method("record_victory"):
			host.record_victory()
		ui.show_victory()

func navigate_victory(to_menu: bool) -> void:
	if not victory_started or victory_navigation:
		return
	victory_navigation = true
	if is_instance_valid(victory_music_tween):
		victory_music_tween.kill()
	var fade := create_tween().set_parallel(true)
	fade.tween_property(ui.victory_screen, "modulate:a", 0.0, 0.2)
	if music_player != null:
		fade.tween_property(music_player, "volume_db", -60.0, 0.2)
	await fade.finished
	get_tree().paused = false
	var host := get_tree().current_scene
	if host.has_method("retry"):
		if to_menu:
			host.main_menu()
		else:
			host.retry()
	elif to_menu:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().reload_current_scene()
