extends Node
## Autoload probe used only by test_native_display_startup.py; main scene is real.
var failures := 0
var checks := 0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
	else:print("PASS: "+message)
func run() -> void:
	await get_tree().create_timer(.4).timeout
	var window := get_tree().root
	var settings := get_node("/root/GameSettings")
	var session := get_node("/root/Session")
	var menu := get_tree().current_scene
	check(menu!=null and menu.scene_file_path==ProjectSettings.get_setting("application/run/main_scene"),"normal engine bootstrap loads configured main menu, without a replacement MainLoop")
	check(not Engine.is_editor_hint(),"game runs independently of the editor")
	check(settings.values.display_mode==1 and settings.current_display_mode()==1,"fullscreen preference restored at normal application startup")
	check(DisplayServer.window_get_size()==DisplayServer.screen_get_size() and DisplayServer.window_get_position()==DisplayServer.screen_get_position(),"standalone native client fills the monitor at startup")
	var transform := window.get_stretch_transform()
	var rendered := transform*window.get_visible_rect()
	check(rendered.position.length()<1 and rendered.size.distance_to(Vector2(DisplayServer.screen_get_size()))<1 and is_equal_approx(transform.x.length(),transform.y.length()),"normal application framebuffer fills the monitor without distortion")
	check(menu.size==menu.get_node("Background").size and menu.size==window.get_visible_rect().size,"real menu and background cover the full logical viewport")
	await RenderingServer.frame_post_draw
	var frame := window.get_texture().get_image()
	check(frame.get_size()==DisplayServer.screen_get_size(),"normal application renders native-resolution pixels")
	var path := OS.get_environment("CATSSAGA_DISPLAY_CAPTURE")
	if not path.is_empty():frame.save_png(path)
	print("NATIVE DISPLAY READY ",DisplayServer.window_get_size()," ",DisplayServer.window_get_position())
	# Allow the external runner to inspect the OS window, rather than trust flags.
	await get_tree().create_timer(1).timeout
	settings.toggle_fullscreen()
	await get_tree().create_timer(.2).timeout
	check(DisplayServer.window_get_size()==Vector2i(960,540) and not window.borderless,"normal application restores saved window size when toggled")
	settings.confirm_display()
	session.options_dialog.hide()
	settings.toggle_fullscreen()
	await get_tree().create_timer(.2).timeout
	settings.confirm_display()
	session.options_dialog.hide()
	check(settings.current_display_mode()==1 and DisplayServer.window_get_size()==DisplayServer.screen_get_size(),"normal application returns to native fullscreen and saves it for next launch")
	print("NATIVE DISPLAY STARTUP: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
