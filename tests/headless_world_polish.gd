extends SceneTree
var checks := 0
var failures := 0
var session: Node
var ambience: Node
func _initialize() -> void:
 create_timer(150).timeout.connect(func():push_error("World polish timeout");quit(1))
 call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks += 1
 if not ok:failures += 1;push_error("FAIL: "+message)
func settle() -> void:
 await physics_frame
 await physics_frame
 await process_frame
func run() -> void:
 session = root.get_node("Session")
 ambience = root.get_node("Ambience")
 session.saves.save_path = "user://world-polish-test.json"
 var old_enabled: bool = ambience.enabled
 ambience.set_enabled(false)
 ambience.enabled = true
 ambience.load_settings()
 check(not ambience.enabled,"ambience off persists through settings reload")
 ambience.set_enabled(true)
 await session.new_game()
 await settle()
 check(ambience.profile == "forest","Forest Entrance selects nature ambience")
 await create_timer(1.8).timeout
 check(float(ambience.weights.get("forest",0))>.9 and not ambience.voices.is_empty(),"licensed ambient layer fades in")
 var voices_before: int = ambience.voices.size()
 await session.travel("deep_forest","FromEntrance")
 await settle()
 check(ambience.profile == "forest" and ambience.voices.size()>=voices_before,"same nature profile is preserved over transition")
 var world: Node = current_scene
 check(not get_nodes_in_group("destination_signs").is_empty(),"old regions receive physical signposts")
 for portal in world.map.get_node("Portals").get_children():
  var sign: Node = world.map.get_node_or_null("Sign_"+str(portal.name))
  check(sign != null and sign.route == portal,"sign retains original route "+str(portal.name))
  for label in portal.find_children("*","Label",true,false):check(not label.visible,"floating destination label hidden")
 var sign: Node = world.map.get_node("Sign_ToFlooded")
 session.unrestricted_region_access = false
 var flags: Dictionary = session.story_flags.duplicate(true)
 check(sign.read_text().contains("Flooded Forest") and sign.read_text().contains("locked"),"sign reports live locked route")
 world.player.position = sign.position+Vector2(-25,25)
 await settle()
 check(world.nearest_npc == sign,"nearby physical sign is selected by the existing interaction system")
 var read_key := InputEventKey.new()
 read_key.keycode = KEY_Z
 read_key.pressed = true
 Input.parse_input_event(read_key)
 Input.flush_buffered_events()
 await process_frame
 read_key.pressed = false
 Input.parse_input_event(read_key)
 Input.flush_buffered_events()
 check(world.dialogue.active and world.dialogue.lines[0].text.contains("Flooded Forest"),"Z sign handler opens existing dialogue UI")
 check(flags == session.story_flags,"sign changes no progression flags")
 world.dialogue._finish("")
 await session.travel("entrance","Start")
 await settle()
 world = current_scene
 var player: Node = world.player
 var shape: Shape2D = player.get_node("CollisionShape2D").shape
 var movement: Node = player.get_node("MovementVisual")
 check(movement.shadow != null,"overworld player has one grounding shadow")
 var original_speed: float = player.speed
 player.movement_locked = false
 var key := InputEventKey.new()
 key.keycode = KEY_D;key.pressed = true
 Input.parse_input_event(key);Input.flush_buffered_events()
 await create_timer(.25).timeout
 key.pressed = false;Input.parse_input_event(key);Input.flush_buffered_events()
 check(player.speed == original_speed and player.get_node("CollisionShape2D").shape == shape,"movement polish leaves speed and collision resource unchanged")
 check(not movement.prints.is_empty(),"moving player leaves human pawprints")
 await create_timer(2.8).timeout
 check(movement.prints.is_empty(),"footprints expire rather than accumulating")
 await session.travel("underground_cave","FromFlooded")
 await settle()
 check(ambience.profile == "cave","cave selects licensed drips and reverb")
 check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("CaveAmbience")) == 1,"cave ambience has dedicated reverb without altering music bus")
 var options := preload("res://scripts/ui/options_dialog.gd").new()
 root.add_child(options)
 options.open()
 var toggle: CheckButton = options.find_child("AmbienceToggle",true,false)
 check(toggle != null and toggle.button_pressed,"Options exposes current ambience state")
 toggle.button_pressed = false
 check(not ambience.enabled,"Options toggle disables ambience")
 await create_timer(1.6).timeout
 var all_quiet := true
 for voice in ambience.voices:
  if voice.player.volume_db > -70:all_quiet = false
 check(all_quiet,"disabling ambience fades every active voice")
 options.queue_free()
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/wonderland_human/polish-provenance.json"))
 for path in manifest.files:check(FileAccess.get_sha256("res://"+path) == manifest.files[path].sha256,"human source bytes preserved: "+path)
 for file in ["ComboWind","birdsongnl","robin2","bluejay","Crickets_At_NightCombo","Spooky_Water_Drops","drippingwater_drip_a","drippingwater_drip_b","lake_waves_2_calm","small_waterfall"]:
  var stream: AudioStream = load("res://assets/ambience_human/"+file+".ogg")
  check(stream != null and stream.get_length()>0,"Godot decodes human recording "+file)
 ambience.set_enabled(old_enabled)
 await session.main_menu()
 await settle()
 check(ambience.profile.is_empty(),"ambient profiles stop in main menu")
 var menu: Node = current_scene
 menu._show_info()
 menu._show_credits()
 check(menu.info_content.text.contains("LLiosette"),"creator credit is preserved")
 menu._open_asset_credits()
 var credits: AcceptDialog = menu.get_node("AssetCreditsDialog")
 check(credits.get_node("AssetNotices").text.contains("Icons made by Lorc") and credits.get_node("AssetNotices").text.contains("Mike Koenig"),"exported in-game credits include icon and audio attribution")
 menu._open_asset_credits()
 check(menu.get_node("AssetCreditsDialog") == credits,"reopening credits reuses the existing dialog")
 credits.hide()
 await process_frame
 print("WORLD POLISH: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
