# Requires a graphical display. Output directory is supplied after --.
# godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
#   --script res://tests/render_ui.gd -- --output=/tmp/catsSaga-review
extends SceneTree

var output_directory: String = "user://ui-review"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI screenshots require a graphical display")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_directory)
	create_timer(45.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_directory.path_join(filename + ".png"))
	print("SCREENSHOT ", filename, " ", error)
	if error != OK:
		quit(1)

func run() -> void:
	root.size = Vector2i(540, 900)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(1.0).timeout
	await snapshot("polish-menu")
	current_scene._show_info()
	await create_timer(0.3).timeout
	await snapshot("polish-info-controls")
	current_scene._show_credits()
	await snapshot("polish-info-credits")
	current_scene._back_to_menu()
	current_scene._start_game()
	await create_timer(0.5).timeout
	var game = current_scene
	game.player.invincible = true
	await create_timer(1.8).timeout
	await snapshot("polish-opening")
	while not game.boss_spawned:
		await process_frame
	await snapshot("polish-entrance")
	await create_timer(0.15).timeout
	await snapshot("polish-bounce")
	await create_timer(0.5).timeout
	await snapshot("polish-gameplay")
	game.player.invincible = false
	game.player.take_damage(1)
	game.boss.take_damage(45)
	await create_timer(0.4).timeout
	await snapshot("polish-damaged")
	game.player.invincible = true
	game.player.unlimited_saturate = true
	game.player.activate_saturate()
	await create_timer(0.65).timeout
	await snapshot("polish-saturate")
	await create_timer(1.2).timeout
	game.music_player.stop()
	await create_timer(0.3).timeout
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
