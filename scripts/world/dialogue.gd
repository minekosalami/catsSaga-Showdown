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
var text_label: RichTextLabel
var prompt_label: Label
var database: Dictionary = {}
@export var typing_sound: AudioStream
@export_range(1, 20) var characters_per_sound: int = 6
@export_range(0.5, 2.0) var typing_pitch: float = 1.0
@export_range(-60.0, 0.0) var typing_volume_db: float = -20.0
@export_range(0.03, 0.5) var sound_interval: float = 0.08
var audio: AudioStreamPlayer
var sound_clock: float = 0.0
var last_sound_character: int = 0
var graph: Dictionary = {}
var node_id: String = ""
var outcome: String = ""
var choices: Array = []
var choice_buttons: Array[Button] = []
var selected_choice: int = 0
var choice_container: VBoxContainer
var dialogue_margin: MarginContainer
var history: Array[Dictionary] = []
const Formatter = preload("res://scripts/world/dialogue_format.gd")

func _ready() -> void:
	layer = 10
	audio = AudioStreamPlayer.new()
	add_child(audio)
	database = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/test_dialogue.json"))
	database["bart_encounter"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/evil_bart.json"))
	database["boss2_encounter"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/boss2.json"))
	database["boss2_victory"] = [{"speaker":"Boss 2", "text":"What the hell?? I underestimated you…! Get out of here, me!"}]
	database["boss2_defeated"] = [{"speaker":"Boss 2", "text":"You're not telling anyone about this"}]
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var margin := MarginContainer.new()
	dialogue_margin = margin
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
	text_label = _rich_label(22)
	text_label.custom_minimum_size.y = 80
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(text_label)
	choice_container = VBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 8)
	stack.add_child(choice_container)
	choice_container.hide()
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 14)
	stack.add_child(prompt_label)
	panel.hide()

func start(dialogue_id: String, voice: AudioStream = null) -> void:
	if active or not database.has(dialogue_id):
		return
	if database[dialogue_id] is Dictionary:
		start_graph(database[dialogue_id], voice)
	else:
		start_lines(database[dialogue_id], voice)

func start_lines(content: Array, voice: AudioStream = null) -> void:
	if active or content.is_empty():
		return
	graph = {}
	node_id = ""
	outcome = ""
	history.clear()
	_clear_choices()
	lines = content
	line_index = 0
	active = true
	audio.stream = voice if voice != null else typing_sound
	audio.pitch_scale = typing_pitch
	audio.volume_db = typing_volume_db
	panel.show()
	_show_line()

func _show_line() -> void:
	speaker_label.text = "> " + lines[line_index]["speaker"]
	_clear_choices()
	var raw: String = lines[line_index]["text"]
	text_label.text = Formatter.format_text(raw)
	history.append({"speaker": lines[line_index]["speaker"], "text": raw, "formatted": text_label.text, "node": node_id})
	audio.stop()
	sound_clock = 0.0
	last_sound_character = 0
	revealed = 0.0
	text_label.visible_characters = 0

func _process(delta: float) -> void:
	if not active:
		return
	revealed = minf(revealed + characters_per_second * delta, text_label.get_total_character_count())
	text_label.visible_characters = int(revealed)
	sound_clock += delta
	if is_revealed():
		audio.stop()
	elif audio.stream != null and not audio.playing and sound_clock >= sound_interval and text_label.visible_characters - last_sound_character >= characters_per_sound:
		audio.play()
		last_sound_character = text_label.visible_characters
		sound_clock = 0.0
	cursor_clock += delta
	prompt_label.text = ("UP / DOWN  Select   Z  Confirm" if not choices.is_empty() else "Z  " + ("advance" if is_revealed() else "reveal")) + ("  _" if fmod(cursor_clock, 1.0) < 0.5 else "   ")

func is_revealed() -> bool:
	return text_label.visible_characters >= text_label.get_total_character_count()

func advance() -> void:
	if not active or not choices.is_empty():
		return
	audio.stop()
	if not is_revealed():
		revealed = text_label.get_total_character_count()
		text_label.visible_characters = int(revealed)
		return
	line_index += 1
	if line_index >= lines.size():
		if graph.is_empty():
			_finish("")
		else:
			var node: Dictionary = graph.nodes[node_id]
			if node.has("choices"):
				line_index = lines.size() - 1
				_show_choices(node.choices)
			elif node.has("next"):
				_show_node(node.next)
			else:
				_finish(node.get("end", ""))
	else:
		_show_line()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed:
		return
	if event.keycode not in [KEY_Z, KEY_UP, KEY_DOWN]:
		return
	get_viewport().set_input_as_handled()
	if event.echo:
		return
	if not choices.is_empty():
		if event.keycode == KEY_Z:
			_choose(selected_choice)
		else:
			selected_choice = posmod(selected_choice + (1 if event.keycode == KEY_DOWN else -1), choices.size())
			choice_buttons[selected_choice].grab_focus()
	elif event.keycode == KEY_Z:
		advance()

func _rich_label(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", preload("res://scripts/ui/sketch_theme.gd").UI_FONT)
	var bold := FontVariation.new()
	bold.base_font = preload("res://scripts/ui/sketch_theme.gd").UI_FONT
	bold.variation_embolden = 1.0
	label.add_theme_font_override("bold_font", bold)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	return label

func start_graph(content: Dictionary, voice: AudioStream = null) -> void:
	if active:
		return
	# The same renderer handles linear entries inside each graph node.
	start_lines([{"speaker": "", "text": ""}], voice)
	history.clear()
	graph = content
	_show_node(content.start)

func _show_node(identifier: String) -> void:
	node_id = identifier
	var node: Dictionary = graph.nodes[identifier]
	lines = []
	for text in node.lines:
		lines.append({"speaker": node.speaker, "text": text})
	line_index = 0
	_show_line()

func _clear_choices() -> void:
	choices = []
	choice_buttons.clear()
	if choice_container != null:
		for child in choice_container.get_children():
			choice_container.remove_child(child)
			child.queue_free()
		choice_container.hide()
		dialogue_margin.offset_top = -230

func _show_choices(content: Array) -> void:
	choices = content
	selected_choice = 0
	dialogue_margin.offset_top = -360
	choice_container.show()
	for index in range(content.size()):
		var button := Button.new()
		button.set_script(preload("res://scripts/ui/sketch_button.gd"))
		button.custom_minimum_size.y = 42
		button.pressed.connect(_choose.bind(index))
		choice_container.add_child(button)
		var label := _rich_label(18)
		label.text = Formatter.format_text(content[index].text)
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 48
		label.offset_right = -36
		label.offset_top = 8
		choice_buttons.append(button)
	choice_buttons[0].grab_focus()

func _choose(index: int) -> void:
	if not active or choices.is_empty():
		return
	var choice: Dictionary = choices[index]
	history.append({"speaker": "", "text": choice.text, "formatted": Formatter.format_text(choice.text), "node": node_id})
	_clear_choices()
	if choice.has("next"):
		_show_node(choice.next)
	else:
		_finish(choice.get("end", ""))

func _finish(result: String) -> void:
	outcome = result
	audio.stop()
	active = false
	_clear_choices()
	panel.hide()
	finished.emit()
