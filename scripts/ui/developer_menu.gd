extends CanvasLayer

var opened := false
var overlay: Control
var panel: PanelContainer
var scroll: ScrollContainer
var controls: Dictionary = {}
var status: Label
var seek_time: SpinBox
var was_paused := false
var opening_scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,.8)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Developer Menu"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",24)
	column.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	var groups := {"Player":["CATA","BEAM","mycoordinates","hitbox"],"World / Map":["thefogisleaving","reveal_locations","anywhereiwant"]}
	for group in groups:
		_add_heading(list,group)
		for code in groups[group]:
			_add_entry(list,code,Session.developer_cheats.LABELS[code],Session.developer_cheats.DESCRIPTIONS[code],true)
	_add_heading(list,"Other · debug previews")
	var cue = preload("res://scripts/blankkitten/timeline.gd")
	for index in cue.STARTS.size():
		_add_entry(list,"seek:"+str(index),"BlankKitten · "+cue.NAMES[index],"Ctrl+Shift+%d · %.2fs · debug preview" % [index+1,cue.STARTS[index]],false)
	seek_time = SpinBox.new()
	seek_time.max_value = cue.END-.01
	seek_time.step = .01
	seek_time.suffix = "seconds"
	list.add_child(seek_time)
	var seek_button := Button.new()
	seek_button.text = "BlankKitten · Preview timestamp"
	seek_button.pressed.connect(func():
		status.text = Session.developer_cheats.seek(seek_time.value)
		_suspend_preview()
	)
	list.add_child(seek_button)
	controls["seek:custom"] = seek_button
	status = Label.new()
	status.custom_minimum_size.y = 38
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",14)
	column.add_child(status)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close  [ - / Esc ]"
	close.pressed.connect(close_menu)
	column.add_child(close)
	get_viewport().size_changed.connect(_layout)
	_layout()
	overlay.hide()

func _add_heading(list: VBoxContainer, title: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size",18)
	list.add_child(heading)

func _add_entry(list: VBoxContainer, code: String, title: String, description: String, toggle: bool) -> void:
	var button: Button = CheckButton.new() if toggle else Button.new()
	button.text = title
	button.name = code.replace(":","_")
	button.custom_minimum_size.y = 38
	button.set_meta("title",title)
	button.pressed.connect(func():
		status.text = Session.developer_cheats.activate(code)
		_suspend_preview()
		_sync()
	)
	list.add_child(button)
	controls[code] = button
	var hint := Label.new()
	hint.text = description
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",12)
	list.add_child(hint)

func _suspend_preview() -> void:
	var battle: Node = Session.developer_cheats.context().battle
	if battle != null:
		Session._suspend_always(battle)
		# AudioStreamPlayer.play() inside the existing seek can restart a paused voice.
		if get_tree().paused: battle.music_player.stream_paused = true

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x = minf(460,viewport_size.x-40)
	scroll.custom_minimum_size.y = clampf(viewport_size.y-190,80,380)

func can_open() -> bool:
	if Session.busy or is_instance_valid(Session.confirmation) or (is_instance_valid(Session.options_dialog) and Session.options_dialog.visible): return false
	var target := Session.developer_cheats.context()
	if target.world != null:
		return not target.world.checking_spawn and not target.world.dialogue.active and not target.world.awaiting_victory_dialogue and not target.world.map_modal_open()
	return target.battle != null and not target.battle.game_over and not target.battle.victory_started

func show_menu() -> void:
	if opened or not can_open(): return
	opening_scene = get_tree().current_scene
	was_paused = get_tree().paused
	var battle: Node = Session.developer_cheats.context().battle
	if not was_paused and battle != null: Session._suspend_always(battle)
	get_tree().paused = true
	opened = true
	status.text = "Gameplay paused. Unavailable cheats are disabled."
	_sync()
	overlay.show()

func close_menu() -> void:
	if not opened: return
	opened = false
	overlay.hide()
	if not was_paused: Session.restore_suspended_modes()
	get_tree().paused = was_paused
	opening_scene = null

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_developer_menu") and not event.is_echo():
		if opened: close_menu()
		else: show_menu()
		return true
	if not opened: return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE: close_menu()
		# Letter/space shortcuts cannot type cheats or activate focused buttons while paused.
		return (event.keycode >= KEY_A and event.keycode <= KEY_Z) or event.keycode in [KEY_SPACE,KEY_ESCAPE]
	return false

func _sync() -> void:
	for code in controls:
		var state: Dictionary = Session.developer_cheats.state(code)
		var button: Button = controls[code]
		button.disabled = not state.available
		if button is CheckButton:
			button.set_pressed_no_signal(state.active)
			button.text = str(button.get_meta("title")) + ("  [ON]" if state.active else "  [OFF]")
	seek_time.editable = Session.developer_cheats.state("seek:0").available

func _process(_delta: float) -> void:
	if not opened: return
	if Session.busy or get_tree().current_scene != opening_scene:
		close_menu()
		return
	_sync()
