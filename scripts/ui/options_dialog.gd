extends AcceptDialog
const Style = preload("res://scripts/ui/menu/theme.gd")
var tabs: TabContainer
var settings: Node
var controls := {}
var status: Label
var trial_status: Label
var keep: Button
var revert: Button
var display_mode_picker: OptionButton
var resolution: OptionButton
var resolutions: Array[Vector2i]=[]
var capture_action := ""
var capture_button: Button

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	settings=get_node("/root/GameSettings")
	title="Settings"
	theme=Style.create()
	exclusive=true
	get_ok_button().text="Back"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	add_child(body)
	tabs=TabContainer.new()
	tabs.custom_minimum_size=Vector2(740,430)
	body.add_child(tabs)
	_build_display(section("Display"))
	_build_audio(section("Audio"))
	_build_controls(section("Controls"))
	_build_comfort(section("Gameplay"))
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y=28
	status.add_theme_font_size_override("font_size",13)
	body.add_child(status)
	Style.button(body,"Restore All Defaults",func():Session.confirm_action("Restore display, audio, controls and accessibility defaults?",func():settings.restore_defaults();refresh())).custom_minimum_size.y=42
	settings.changed.connect(refresh)
	settings.display_trial_changed.connect(refresh)
	visibility_changed.connect(func():
		if not visible:
			capture_action=""
			if settings.trial:settings.revert_display()
	)
	refresh()
func section(title_text: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name=title_text
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	margin.add_child(column)
	return column
func label(parent: Node,text: String) -> Label:
	var node := Label.new()
	node.text=text
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node
func row(parent: Node,text: String,node: Control) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",24)
	parent.add_child(line)
	var caption := label(line,text)
	caption.custom_minimum_size.x=285
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.x=270
	line.add_child(node)
func _build_display(parent: Node) -> void:
	display_mode_picker=OptionButton.new()
	display_mode_picker.add_item("Windowed",0)
	display_mode_picker.add_item("Borderless fullscreen",1)
	if settings.exclusive_supported():display_mode_picker.add_item("Exclusive fullscreen",2)
	row(parent,"Display mode",display_mode_picker)
	resolution=OptionButton.new()
	resolutions=settings.resolution_options()
	if resolutions.is_empty():resolutions.append(Vector2i(1280,720))
	for size in resolutions:resolution.add_item("%d × %d"%[size.x,size.y])
	row(parent,"Window resolution",resolution)
	display_mode_picker.item_selected.connect(func(i):resolution.disabled=display_mode_picker.get_item_id(i)!=0)
	Style.button(parent,"Apply Display",func():settings.preview_display(display_mode_picker.get_selected_id(),resolutions[resolution.selected])).custom_minimum_size.y=44
	label(parent,"Fullscreen uses the current monitor resolution.\nAlt + Enter toggles fullscreen. Changes revert after 12 seconds.")
	trial_status=label(parent,"")
	var buttons := HBoxContainer.new()
	parent.add_child(buttons)
	keep=Style.button(buttons,"Keep",settings.confirm_display)
	revert=Style.button(buttons,"Revert",settings.revert_display)
	for b in [keep,revert]:b.custom_minimum_size=Vector2(180,42)
	var zoom := OptionButton.new()
	for item in ["100% — Original","90% — Slightly wider","80% — Wider","75% — Maximum visibility"]:zoom.add_item(item)
	zoom.item_selected.connect(func(i):settings.set_value("zoom",[1.0,.9,.8,.75][i]))
	row(parent,"Exploration visibility",zoom)
	controls.zoom=zoom
	label(parent,"Zoom changes exploration only; HUD and battle resolution stay fixed.\nInternal battle rendering remains 540 × 900. No render-scale override.")
func _build_audio(parent: Node) -> void:
	for key in ["master","music","sfx"]:
		var slider := HSlider.new()
		slider.min_value=0
		slider.max_value=100
		slider.step=1
		slider.custom_minimum_size.y=38
		slider.value_changed.connect(func(value):settings.set_value(key,value/100.0))
		row(parent,{"master":"Master volume","music":"Music volume","sfx":"Sound effects / ambience"}[key],slider)
		controls[key]=slider
	var ambient := CheckButton.new()
	ambient.text="Environmental ambience"
	ambient.toggled.connect(get_node("/root/Ambience").set_enabled)
	parent.add_child(ambient)
	controls.ambient=ambient
func _build_controls(parent: Node) -> void:
	label(parent,"Select a binding, then press a key. Escape cancels.\nArrows / D-pad navigate menus; Enter / A confirms; Escape / B goes back.")
	for action in settings.ACTIONS:
		var button := Button.new()
		button.custom_minimum_size.y=44
		button.pressed.connect(func():
			capture_action=action
			capture_button=button
			button.text="Press a key…"
		)
		row(parent,settings.LABELS[action],button)
		controls[action]=button
	label(parent,"Controller: left stick / D-pad move; A attack, jump or interact;\nB SATURATE / Endure sprint; LB focus; Y inventory; Back map; Start pause.\nTyped cheats and the minus-key developer menu remain available.")
	Style.button(parent,"Restore Control Defaults",func():Session.confirm_action("Restore default controls?",func():settings.bindings.clear();settings.install_actions();settings.save_preferences();refresh()))
func _build_comfort(parent: Node) -> void:
	for pair in [["flashing","Reduced flashing"],["shake","Camera shake"]]:
		var toggle := CheckButton.new()
		toggle.text=pair[1]
		toggle.toggled.connect(func(value):settings.set_value(pair[0],value))
		parent.add_child(toggle)
		controls[pair[0]]=toggle
	var reduced := CheckButton.new()
	reduced.text="Reduced battle effects"
	reduced.toggled.connect(get_node("/root/VisualSettings").set_reduced)
	parent.add_child(reduced)
	controls.reduced=reduced
	var motion := HSlider.new()
	motion.min_value=0
	motion.max_value=1
	motion.step=.05
	motion.custom_minimum_size.y=38
	motion.value_changed.connect(get_node("/root/VisualSettings").set_motion)
	row(parent,"Background motion",motion)
	controls.motion=motion
	label(parent,"Comfort options affect presentation only.\nThe original battle-entry animation is preserved.")
func refresh() -> void:
	if not is_node_ready():return
	for key in ["master","music","sfx"]:controls[key].set_value_no_signal(settings.values[key]*100)
	controls.zoom.select([1.0,.9,.8,.75].find(settings.values.zoom))
	for action in settings.ACTIONS:
		if capture_action!=action:controls[action].text=settings.binding_label(action)
	for key in ["flashing","shake"]:controls[key].set_pressed_no_signal(settings.values[key])
	controls.ambient.set_pressed_no_signal(get_node("/root/Ambience").enabled)
	controls.reduced.set_pressed_no_signal(get_node("/root/VisualSettings").reduced)
	controls.motion.set_value_no_signal(get_node("/root/VisualSettings").motion)
	var current := DisplayServer.window_get_mode()
	display_mode_picker.select(2 if current==DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else (1 if current==DisplayServer.WINDOW_MODE_FULLSCREEN else 0))
	resolution.disabled=display_mode_picker.get_selected_id()!=0
	var index: int=resolutions.find(DisplayServer.window_get_size())
	resolution.select(maxi(0,index))
	keep.visible=settings.trial
	revert.visible=settings.trial
	if settings.trial:tabs.current_tab=0;keep.grab_focus()
	status.text=settings.last_error
func open(tab: int=0) -> void:
	tabs.current_tab=tab
	refresh()
	popup_centered(Vector2i(800,590))
	if settings.trial:keep.grab_focus()
	else:get_ok_button().grab_focus()
func _process(_delta: float) -> void:
	trial_status.text="Keep these display settings? %d seconds"%ceili(settings.trial_seconds) if settings.trial else ""
func _input(event: InputEvent) -> void:
	if not visible:return
	if event is InputEventKey and event.pressed and not event.echo and ((event.alt_pressed and event.keycode==KEY_ENTER) or event.keycode==KEY_F11):
		settings._input(event)
		get_viewport().set_input_as_handled()
		return
	if not capture_action.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var error: String = "" if event.keycode==KEY_ESCAPE else settings.bind_key(capture_action,event.keycode)
		capture_action=""
		refresh()
		status.text=error
	elif event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
