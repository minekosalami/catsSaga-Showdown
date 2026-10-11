extends CanvasLayer

var opened: bool = false
var overlay: Control
var buttons: Dictionary = {}
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 380
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "// PAUSED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)
	for entry in [
		["Resume", "RESUME()", Session.close_pause],
		["Save", "SAVE()", _save],
		["Load", "LOAD()", _load],
		["Options", "OPTIONS()", Session.open_options],
		["MainMenu", "MAIN_MENU()", Session.request_main_menu]
	]:
		var button := Button.new()
		button.set_script(preload("res://scripts/ui/sketch_button.gd"))
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(360, 52)
		button.pressed.connect(entry[2])
		content.add_child(button)
		buttons[entry[0]] = button
	status = Label.new()
	status.custom_minimum_size = Vector2(360, 48)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	content.add_child(status)
	overlay.hide()

func show_menu(in_combat: bool) -> void:
	opened = true
	buttons.Save.disabled = in_combat
	buttons.Load.disabled = in_combat or Session.saves.read_save().is_empty()
	status.text = "Saving and loading are available in the forest." if in_combat else ""
	overlay.show()
	buttons.Resume.grab_focus()

func hide_menu() -> void:
	opened = false
	overlay.hide()

func _save() -> void:
	status.text = "Saved." if Session.save_current() else Session.saves.last_error
	buttons.Load.disabled = Session.saves.read_save().is_empty()

func _load() -> void:
	var action := func(): Session.load_game()
	if Session.has_unsaved_progress():
		Session.confirm_action("Load the saved game and discard unsaved progress?", action)
	else:
		action.call()
