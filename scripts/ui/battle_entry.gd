extends Control
## Persistent viewport overlay. Neither music nor combat runs under this curtain.
signal stage_changed(stage: String)
var stage := "idle"
var background: ColorRect
var cat: Sprite2D
var star: Node2D
var flash: ShaderMaterial
var sounds: Array[AudioStreamPlayer] = []
var source_sprite: Sprite2D
var source_player: CanvasItem
var source_visible := true
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var motion: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cat = Sprite2D.new()
	add_child(cat)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://shaders/encounter_flash.gdshader")
	cat.material = flash
	# Reuse the game's existing star renderer, with all its gameplay/input disabled.
	star = preload("res://scripts/blankkitten/star.gd").new()
	star.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(star)
	star.set_process_input(false)
	for i in range(3):
		var sound := AudioStreamPlayer.new()
		sound.stream = preload("res://scripts/ui/encounter_sounds.gd").make(i)
		sound.volume_db = -24.0 if i == 1 else -18.0
		add_child(sound)
		sounds.append(sound)
	hide()

func mark(value: String) -> void:
	stage = value
	stage_changed.emit(value)

func sprite_for(scene: Node) -> Sprite2D:
	if scene == null: return null
	if scene.name == "Overworld": return scene.player.sprite
	if scene.has_method("finish_entry"):
		return scene.battle.player.find_child("Sprite2D", true, false) as Sprite2D
	return null

func sprite_transform(sprite: Sprite2D, scene: Node) -> Transform2D:
	var transform := sprite.get_global_transform_with_canvas()
	if scene.has_method("finish_entry"):
		transform = scene.arena_container.get_global_transform_with_canvas() * transform
	return get_global_transform_with_canvas().affine_inverse() * transform

func copy_cat(sprite: Sprite2D, transform: Transform2D) -> void:
	cat.texture = sprite.texture
	cat.hframes = sprite.hframes
	cat.vframes = sprite.vframes
	cat.frame = sprite.frame
	cat.centered = sprite.centered
	cat.offset = sprite.offset
	cat.flip_h = sprite.flip_h
	cat.flip_v = sprite.flip_v
	cat.transform = transform

func capture(scene: Node) -> void:
	source_sprite = sprite_for(scene)
	source_player = null
	if scene != null:
		if scene.name == "Overworld": source_player = scene.player
		elif scene.has_method("finish_entry"): source_player = scene.battle.player
	flash.set_shader_parameter("flash", 0.0)
	cat.modulate = Color.WHITE
	if source_sprite != null:
		copy_cat(source_sprite, sprite_transform(source_sprite, scene))
	else:
		# Debug launches from a menu or Sequence retry have no cat sprite.
		cat.texture = preload("res://assets/bartplayer.png")
		cat.transform = Transform2D(0, Vector2.ONE * 56.0 / cat.texture.get_height(), 0, size * 0.5)
		cat.offset = Vector2.ZERO
		cat.hframes = 1
		cat.vframes = 1
		cat.centered = true
		cat.flip_h = false
		cat.flip_v = false
		if scene != null and scene.has_method("finish_entry"):
			cat.position = destination(scene)
	if source_player != null:
		source_visible = source_player.visible
		source_player.hide()
	start_point = cat.position + cat.transform.basis_xform(cat.offset)
	star.position = start_point
	star.scale = Vector2.ONE * 1.4
	star.modulate = Color.WHITE
	star.hide()
	cat.show()
	background.modulate.a = 0.0
	show()
	mark("freeze")

func blackout() -> void:
	await get_tree().create_timer(0.08).timeout
	mark("blackout")
	motion = create_tween()
	motion.tween_property(background, "modulate:a", 1.0, 0.20)
	await motion.finished
	mark("cat_flash")
	flash.set_shader_parameter("flash", 1.0)
	sounds[0].play()
	await get_tree().create_timer(0.06).timeout
	cat.hide()
	star.show()
	await get_tree().create_timer(0.06).timeout
	mark("loading")

func destination(host: Node) -> Vector2:
	var sprite := sprite_for(host)
	if sprite != null:
		var transform := sprite_transform(sprite, host)
		return transform * sprite.offset
	# Sequence has a procedural star rather than a Sprite2D player.
	var transform: Transform2D = host.arena_container.get_global_transform_with_canvas() * host.battle.player.get_global_transform_with_canvas()
	return get_global_transform_with_canvas().affine_inverse() * transform.origin

func arrive(host: Node) -> void:
	end_point = destination(host)
	mark("travel")
	sounds[1].play()
	motion = create_tween()
	motion.tween_property(star, "position", end_point, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	mark("star_flash")
	star.modulate = Color(5, 5, 5, 1)
	await get_tree().create_timer(0.035).timeout
	var sprite := sprite_for(host) if is_instance_valid(host) else null
	if sprite != null:
		copy_cat(sprite, sprite_transform(sprite, host))
	else:
		cat.position = end_point
		cat.offset = Vector2.ZERO
	star.hide()
	cat.show()
	flash.set_shader_parameter("flash", 1.0)
	sounds[2].play()
	mark("cat_return")
	await get_tree().create_timer(0.065).timeout
	# Reveal the initialized, stationary player under the white cat flash.
	mark("reveal")
	motion = create_tween().set_parallel(true)
	motion.tween_property(background, "modulate:a", 0.0, 0.10)
	motion.tween_property(cat, "modulate:a", 0.0, 0.10)
	await motion.finished

func clear(restore_source: bool = false) -> void:
	if is_instance_valid(motion): motion.kill()
	if restore_source and is_instance_valid(source_player): source_player.visible = source_visible
	source_sprite = null
	source_player = null
	for sound in sounds: sound.stop()
	hide()
	mark("idle")
