extends CanvasLayer
var opened := false
var overlay: Control
var buttons := {}
var status: Label
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=90
	overlay=Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme=preload("res://scripts/ui/menu/theme.gd").create()
	var background := ColorRect.new()
	background.set_script(preload("res://scripts/ui/menu/background.gd"))
	overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x=400
	column.add_theme_constant_override("separation",14)
	center.add_child(column)
	var title := Label.new()
	title.text="Paused"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	column.add_child(title)
	for entry in [["Resume","Resume",Session.close_pause],["Options","Settings",Session.open_options],["Controls","Controls",_controls],["MainMenu","Return to Main Menu",Session.request_main_menu]]:
		var button := preload("res://scripts/ui/menu/theme.gd").button(column,entry[1],entry[2])
		button.name=entry[0]
		buttons[entry[0]]=button
	status=Label.new()
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",13)
	status.text="Save progress at save stars."
	column.add_child(status)
	overlay.hide()
func show_menu(_in_combat: bool) -> void:
	opened=true
	overlay.show()
	buttons.Resume.grab_focus()
func hide_menu() -> void:
	opened=false
	overlay.hide()
func _controls() -> void:
	Session.open_options()
	Session.options_dialog.tabs.current_tab=2
