extends SceneTree
var session: Node
func _initialize():
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute("res://docs/review/story-update")
	run.call_deferred()
func capture(label):
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/review/story-update/"+label+".png")
func focus(point):
	current_scene.player.position=point
	var camera=current_scene.player.get_node("Camera2D")
	camera.reset_smoothing();camera.force_update_scroll()
func run():
	root.size=Vector2i(1280,720)
	session=root.get_node("Session")
	await session.new_game(3)
	await capture("01-smoki")
	focus(Vector2(2635,950));await capture("02-butterscotch")
	await session.travel("deep_forest","Start")
	focus(Vector2(2590,920));await capture("03-pawn-exterior")
	focus(Vector2(3104,1820));await capture("04-cupid")
	current_scene.map.get_node("Characters/Cupid").handle_interaction(current_scene)
	current_scene.dialogue.advance();await capture("05-cupid-dialogue")
	current_scene.dialogue._finish("")
	focus(Vector2(2590,920))
	current_scene.map.get_node("Characters/PAWnShop").handle_interaction(current_scene)
	current_scene.dialogue.advance();current_scene.dialogue.advance()
	await capture("06-shop")
	current_scene.dialogue._finish("")
	current_scene.story_shop._run_away()
	await create_timer(.8).timeout
	current_scene.dialogue.advance();current_scene.dialogue.advance()
	await capture("07-theft")
	current_scene.dialogue._choose(1)
	await create_timer(.8).timeout
	current_scene.story_shop.close()
	await session.travel("flooded_forest","Start")
	focus(Vector2(1936,850));await capture("08-doppelcat")
	await session.travel("bart_area","Start")
	current_scene.dialogue.advance();await capture("09-blankkitten")
	quit()
