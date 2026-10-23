extends Node
## User preferences are independent of all gameplay slots.
signal changed
signal display_trial_changed
const PATH := "user://settings.cfg"
const ACTIONS := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"attack":[KEY_Z],"interact":[KEY_Z],"ability":[KEY_X],"focus":[KEY_SHIFT],"world_map":[KEY_M],"inventory":[KEY_SPACE]}
const LABELS := {"move_left":"Move left","move_right":"Move right","move_up":"Move up","move_down":"Move down","attack":"Attack / Sequence jump","interact":"Interact / dialogue","ability":"SATURATE / Endure sprint","focus":"Focus / exploration sprint","world_map":"Map","inventory":"Inventory"}
var values := {"display_mode":0,"window_size":Vector2i(1280,720),"window_position":Vector2i(-1,-1),"zoom":1.0,"master":1.0,"music":1.0,"sfx":1.0,"shake":true,"flashing":false}
var bindings := {}
var trial := false
var trial_seconds := 0.0
var previous_display := {}
var last_error := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()
	install_actions()
	for bus_name in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name),"Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Overworld"),"Music")
	for bus_name in ["Ambience","CaveAmbience"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index>=0: AudioServer.set_bus_send(index,"SFX" if bus_name=="Ambience" else "Ambience")
	apply_audio()
	get_tree().node_added.connect(_route_audio)
	_route_tree(get_tree().root)
	if DisplayServer.get_name()!="headless": _restore_display.call_deferred()

func _restore_display() -> void:
	# Restore after root-window initialization, through Window so its cached mode
	# cannot overwrite the backend fullscreen state on the first resize.
	apply_display(values.display_mode,values.window_size)

func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH)!=OK:return
	for key in values:
		var value: Variant = cfg.get_value("settings",key,values[key])
		if typeof(value)!=typeof(values[key]):continue
		if key in ["master","music","sfx"] and (not is_finite(value) or value<0 or value>1):continue
		if key=="zoom" and value not in [1.0,.9,.8,.75]:continue
		if key=="display_mode" and value not in [0,1,2]:continue
		if key=="window_size" and (value.x<640 or value.y<360 or value.x>7680 or value.y>4320):continue
		values[key]=value
	for action in ACTIONS:
		var code: Variant = cfg.get_value("bindings",action,0)
		if code is int and code>0 and code not in [KEY_ESCAPE,KEY_ENTER,KEY_MINUS,KEY_F11]:bindings[action]=code

func save_preferences() -> bool:
	var cfg := ConfigFile.new()
	for key in values:cfg.set_value("settings",key,values[key])
	for action in bindings:cfg.set_value("bindings",action,bindings[action])
	var error := cfg.save(PATH+".tmp")
	if error==OK:error=DirAccess.rename_absolute(PATH+".tmp",PATH)
	last_error = "" if error==OK else "Settings could not be saved (%d)."%error
	return error==OK

func set_value(key: String,value: Variant) -> void:
	values[key]=value
	apply_audio()
	save_preferences()
	changed.emit()

func apply_audio() -> void:
	for pair in [["Master","master"],["Music","music"],["SFX","sfx"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index<0:continue
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,values[pair[1]])))
		AudioServer.set_bus_mute(index,values[pair[1]]<=0)

func _route_tree(node: Node) -> void:
	_route_audio(node)
	for child in node.get_children():_route_tree(child)
func _route_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		_route_player.call_deferred(node)
func _route_player(node: Node) -> void:
	if not is_instance_valid(node):return
	if node.bus==&"Master":node.bus=&"Music" if node.is_in_group("background_music") or node.is_in_group("combat_music") else &"SFX"

func install_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):InputMap.add_action(action,.25)
		InputMap.action_erase_events(action)
		var codes: Array = [bindings[action]] if bindings.has(action) else ACTIONS[action]
		for code in codes:
			var event := InputEventKey.new()
			event.keycode=code
			InputMap.action_add_event(action,event)
		var button := -1
		if action in ["attack","interact"]:button=JOY_BUTTON_A
		if action=="ability":button=JOY_BUTTON_B
		if action=="focus":button=JOY_BUTTON_LEFT_SHOULDER
		if action=="world_map":button=JOY_BUTTON_BACK
		if action=="inventory":button=JOY_BUTTON_Y
		if action.begins_with("move_"):
			var i := ["move_left","move_right","move_up","move_down"].find(action)
			button=[JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN][i]
			var axis := InputEventJoypadMotion.new()
			axis.axis=JOY_AXIS_LEFT_X if i<2 else JOY_AXIS_LEFT_Y
			axis.axis_value=-1 if i%2==0 else 1
			InputMap.action_add_event(action,axis)
		if button>=0:
			var joy := InputEventJoypadButton.new()
			joy.button_index=button
			InputMap.action_add_event(action,joy)
	# The old project replaced ui_accept entirely with Z; explicitly restore
	# Enter and controller A while keeping keyboard confirmation unchanged.
	var accept := InputEventJoypadButton.new()
	accept.button_index=JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept",accept):InputMap.action_add_event("ui_accept",accept)
	for code in [KEY_ENTER,KEY_KP_ENTER]:
		var enter := InputEventKey.new()
		enter.keycode=code
		if not InputMap.action_has_event("ui_accept",enter):InputMap.action_add_event("ui_accept",enter)

func bind_key(action: String,code: int) -> String:
	if code in [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_MINUS,KEY_F11,KEY_NONE]:return "That key is reserved for menus."
	for other in ACTIONS:
		if other==action or (action in ["attack","interact"] and other in ["attack","interact"]):continue
		var keys: Array = [bindings[other]] if bindings.has(other) else ACTIONS[other]
		if code in keys:return "Already used by "+LABELS[other]+"."
	bindings[action]=code
	install_actions()
	save_preferences()
	changed.emit()
	return last_error
func binding_label(action: String) -> String:
	var keys: Array = [bindings[action]] if bindings.has(action) else ACTIONS[action]
	var labels := PackedStringArray()
	for code in keys:labels.append(OS.get_keycode_string(code))
	return " / ".join(labels)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and ((event.alt_pressed and event.keycode==KEY_ENTER) or event.keycode==KEY_F11):
		if not get_node("/root/Session").battle_entry_pending:
			toggle_fullscreen()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if trial:
		trial_seconds-=delta
		if trial_seconds<=0:revert_display()
func exclusive_supported() -> bool:
	return DisplayServer.get_name() in ["X11","Windows","macOS"]
func resolution_options() -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	var screen := DisplayServer.screen_get_size()
	for size in [Vector2i(960,540),Vector2i(1024,576),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		if size.x<=screen.x and size.y<=screen.y:result.append(size)
	return result
func display_state() -> Dictionary:
	return {"mode":DisplayServer.window_get_mode(),"size":DisplayServer.window_get_size(),"position":DisplayServer.window_get_position()}
func apply_display(mode: int,size: Vector2i) -> void:
	var window := get_tree().root
	window.mode=Window.MODE_WINDOWED
	var screen := DisplayServer.screen_get_usable_rect()
	var bounded := Vector2i(clampi(size.x,640,maxi(640,screen.size.x)),clampi(size.y,360,maxi(360,screen.size.y)))
	window.size=bounded
	var pos: Vector2i=values.window_position
	if pos.x<screen.position.x or pos.y<screen.position.y or pos.x+bounded.x>screen.end.x or pos.y+bounded.y>screen.end.y:pos=screen.position+(screen.size-bounded)/2
	window.position=pos
	if mode==1:window.mode=Window.MODE_FULLSCREEN
	elif mode==2 and exclusive_supported():window.mode=Window.MODE_EXCLUSIVE_FULLSCREEN
func preview_display(mode: int,size: Vector2i) -> void:
	if trial:revert_display()
	previous_display=display_state()
	if previous_display.mode==DisplayServer.WINDOW_MODE_WINDOWED:
		values.window_size=previous_display.size
		values.window_position=previous_display.position
	trial=true
	trial_seconds=12.0
	apply_display(mode,size)
	display_trial_changed.emit()
func confirm_display() -> void:
	if not trial:return
	var mode := DisplayServer.window_get_mode()
	values.display_mode=2 if mode==DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else (1 if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else 0)
	if mode==DisplayServer.WINDOW_MODE_WINDOWED:
		values.window_size=DisplayServer.window_get_size()
		values.window_position=DisplayServer.window_get_position()
	trial=false
	save_preferences()
	display_trial_changed.emit()
func revert_display() -> void:
	if not trial:return
	var window := get_tree().root
	window.mode=Window.MODE_WINDOWED
	window.size=previous_display.size
	window.position=previous_display.position
	window.mode=previous_display.mode
	trial=false
	display_trial_changed.emit()
func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	preview_display(0 if fullscreen else 1,values.window_size)
	get_node("/root/Session").open_options()
func restore_defaults() -> void:
	bindings.clear()
	install_actions()
	for pair in [["zoom",1.0],["master",1.0],["music",1.0],["sfx",1.0],["shake",true],["flashing",false]]:values[pair[0]]=pair[1]
	get_node("/root/VisualSettings").set_reduced(false)
	get_node("/root/VisualSettings").set_motion(.8)
	get_node("/root/Ambience").set_enabled(true)
	apply_audio()
	save_preferences()
	changed.emit()
	preview_display(0,Vector2i(1280,720))
