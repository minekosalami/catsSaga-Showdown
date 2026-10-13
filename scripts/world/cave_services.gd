extends CanvasLayer
## A shop placeholder in the existing world; no purchases, inventory or new scene load.
var opened := false
var overlay: Control
var close_button: Button
var world: Node
func _ready():
	layer = 40
	world = get_parent().get_parent()
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var dim := ColorRect.new()
	dim.color = Color(.09,.06,.075,.94)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	margin.add_child(column)
	for text in ["MARKET()","Shop placeholder","The stalls aren't trading yet."]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",28 if text == "MARKET()" else 18)
		column.add_child(label)
	close_button = Button.new()
	close_button.text = "Back to cave · Z / X / Esc"
	close_button.custom_minimum_size = Vector2(370,48)
	close_button.pressed.connect(close_market)
	column.add_child(close_button)
	overlay.hide()
func open_market():
	if opened or Session.busy or Session.cave_event_active: return
	opened = true
	world.player.velocity = Vector2.ZERO
	world.hide_interaction()
	overlay.show()
	close_button.grab_focus()
func close_market():
	opened = false
	overlay.hide()
	world.player.velocity = Vector2.ZERO
func _input(event: InputEvent):
	if not opened: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Z,KEY_X,KEY_ESCAPE]:
		close_market()
		get_viewport().set_input_as_handled()
