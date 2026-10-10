extends CanvasLayer

signal finished
@export var characters_per_second: float = 42.0
var active: bool = false
var lines: Array = []
var line_index: int = 0
var revealed: float = 0.0
var cursor_clock: float = 0.0
var panel: PanelContainer
var speaker_label: Label
var text_label: Label
var prompt_label: Label
var database: Dictionary = {}

func _ready() -> void:
	layer = 10
	database = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/test_dialogue.json"))
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -230
	margin.offset_bottom = -24
	margin.offset_left = 48
	margin.offset_right = -48
	panel = PanelContainer.new()
	margin.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	padding.add_child(stack)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(speaker_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(text_label)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(prompt_label)
	panel.hide()

func start(dialogue_id: String) -> void:
	if active or not database.has(dialogue_id):
		return
	lines = database[dialogue_id]
	line_index = 0
	active = true
	panel.show()
	_show_line()

func _show_line() -> void:
	speaker_label.text = "> " + lines[line_index]["speaker"]
	text_label.text = lines[line_index]["text"]
	revealed = 0.0
	text_label.visible_characters = 0

func _process(delta: float) -> void:
	if not active:
		return
	revealed = minf(revealed + characters_per_second * delta, text_label.get_total_character_count())
	text_label.visible_characters = int(revealed)
	cursor_clock += delta
	prompt_label.text = "E / ENTER  " + ("advance" if is_revealed() else "reveal") + ("  _" if fmod(cursor_clock, 1.0) < 0.5 else "   ")

func is_revealed() -> bool:
	return text_label.visible_characters >= text_label.get_total_character_count()

func advance() -> void:
	if not active:
		return
	if not is_revealed():
		revealed = text_label.get_total_character_count()
		text_label.visible_characters = int(revealed)
		return
	line_index += 1
	if line_index >= lines.size():
		active = false
		panel.hide()
		finished.emit()
	else:
		_show_line()

func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		advance()
		get_viewport().set_input_as_handled()
