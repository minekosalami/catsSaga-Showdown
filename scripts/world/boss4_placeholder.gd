extends Node2D
# No attacks, damage, completion flag, or rewards.
var game_over := false
var victory_started := false
var player: Node2D
var music_player: AudioStreamPlayer
func _ready():
	player = Node2D.new()
	add_child(player)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/player/player.png.png")
	sprite.scale = Vector2.ONE*72/sprite.texture.get_height()
	sprite.position = Vector2(270,650)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(sprite)
	music_player = AudioStreamPlayer.new()
	var silence := AudioStreamWAV.new()
	silence.mix_rate = 22050
	silence.format = AudioStreamWAV.FORMAT_16_BITS
	var data := PackedByteArray()
	data.resize(2048)
	data.fill(0)
	silence.data = data
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 1024
	music_player.stream = silence
	add_child(music_player)
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var background := ColorRect.new()
	background.color = Color("#111116")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 450
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	for text in ["BOSS_4()","Battle placeholder","No combat or rewards yet."]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size",32 if text == "BOSS_4()" else 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	for text in ["Return to cave", "Retry introduction"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.y = 48
		button.pressed.connect(Session.return_cave_placeholder)
		column.add_child(button)
