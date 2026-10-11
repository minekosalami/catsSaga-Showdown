extends CanvasLayer

const Layout = preload("res://scripts/maps/world_layout.gd")
const Canvas = preload("res://scripts/maps/map_canvas.gd")
const CODE := "thefogisleaving"
var world: Node2D
var minimap: Control
var full_map: Control
var map_frame: Control
var inventory: Control
var inventory_contents: Label
var fog_image: Image
var fog_texture: ImageTexture
var opened := false
var inventory_opened := false
var target_zoom := 2.0
var sequence := ""
var sequence_time := 0.0
var last_reveal_cell := Vector2i(-1000,-1000)
var last_area := ""

func setup(host: Node2D) -> void:
	world = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var terrain: Texture2D = load("res://resources/maps/world_terrain.res")
	fog_image = Session.exploration.visibility_image()
	fog_texture = ImageTexture.create_from_image(fog_image)
	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_script(Canvas)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.position = Vector2(24,24)
	minimap.size = Vector2(150,150)
	add_child(minimap)
	minimap.configure(terrain,fog_texture,true)
	map_frame = Control.new()
	map_frame.name = "WorldMap"
	add_child(map_frame)
	map_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_frame.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var paper := ColorRect.new()
	paper.color = Color("#101410")
	map_frame.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "WORLD_MAP()"
	title.position = Vector2(28,18)
	title.add_theme_font_size_override("font_size",26)
	map_frame.add_child(title)
	full_map = Control.new()
	full_map.name = "Terrain"
	full_map.set_script(Canvas)
	full_map.clip_contents = true
	map_frame.add_child(full_map)
	full_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full_map.offset_left = 24
	full_map.offset_top = 64
	full_map.offset_right = -24
	full_map.offset_bottom = -56
	full_map.configure(terrain,fog_texture,false)
	var footer := Label.new()
	footer.text = "ARROWS  Pan   |   SCROLL  Zoom   |   M / ESC  Close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_frame.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -42
	footer.offset_bottom = -12
	map_frame.hide()
	_build_inventory()
	_refresh()

func _build_inventory() -> void:
	inventory = Control.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.78)
	inventory.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	inventory.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(430,230)
	column.add_theme_constant_override("separation",24)
	panel.add_child(column)
	var title := Label.new()
	title.text = "INVENTORY()"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	inventory_contents = Label.new()
	inventory_contents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(inventory_contents)
	var close := Button.new()
	close.text = "CLOSE()  [SPACE / ESC]"
	close.pressed.connect(close_modals)
	column.add_child(close)
	inventory.hide()

func modal_open() -> bool:
	return opened or inventory_opened

func normal_exploration() -> bool:
	return not Session.busy and not get_tree().paused and not world.dialogue.active and not world.awaiting_victory_dialogue and not world.checking_spawn and not Session.world_menu_open()

func update_exploration() -> void:
	if world.checking_spawn: return
	var changed: Array[Rect2i] = Session.exploration.reveal(Session.area_id,world.player.position)
	if changed.is_empty(): return
	for rect in changed:
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x): fog_image.set_pixel(x,y,Color.WHITE)
	fog_texture.update(fog_image)

func open_map() -> void:
	if not normal_exploration(): return
	sequence = ""
	update_exploration()
	opened = true
	target_zoom = 2.0
	full_map.zoom = target_zoom
	full_map.center_world = Layout.world_point(Session.area_id,world.player.position)
	world.player.velocity = Vector2.ZERO
	world.player.movement_locked = true
	map_frame.show()
	# The opaque map covers the world; avoid rendering its sprites underneath.
	world.map.hide()
	world.player.hide()
	world.hide_interaction()
	_refresh()

func close_modals() -> void:
	opened = false
	inventory_opened = false
	map_frame.hide()
	inventory.hide()
	world.map.show()
	world.player.show()
	sequence = ""
	world.player.velocity = Vector2.ZERO
	_refresh()

func handle_input(event: InputEvent) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		sequence = ""
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if modal_open():
			if event.keycode in [KEY_ESCAPE,KEY_X] or (opened and event.keycode == KEY_M) or (inventory_opened and event.keycode == KEY_SPACE): close_modals()
			# All keyboard gameplay input stays inside the active map/inventory modal.
			return true
		if not normal_exploration():
			sequence = ""
			return false
		if event.keycode == KEY_M:
			open_map()
			return true
		if event.keycode == KEY_SPACE:
			sequence = ""
			inventory_opened = true
			inventory_contents.text = "Flooded Forest Key" if Session.story_flags.get("flooded_forest_key_obtained",false) else "No items collected."
			inventory.show()
			world.player.velocity = Vector2.ZERO
			world.player.movement_locked = true
			world.hide_interaction()
			return true
		var code: int = event.keycode
		if code >= KEY_A and code <= KEY_Z:
			var letter := char(code).to_lower()
			if CODE.begins_with(sequence+letter):
				sequence += letter
				sequence_time = 1.6
				world.player.velocity = Vector2.ZERO
				world.player.movement_locked = true
				if sequence == CODE:
					Session.map_reveal_cheat = not Session.map_reveal_cheat
					sequence = ""
				_refresh()
				return true
			sequence = "t" if letter == "t" else ""
		else:
			sequence = ""
	if event is InputEventMouseButton and opened and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: target_zoom = minf(target_zoom*1.20,12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: target_zoom = maxf(target_zoom/1.20,0.8)
		return true
	return false

func _process(delta: float) -> void:
	if world == null: return
	sequence_time -= delta
	if sequence_time <= 0 or not normal_exploration(): sequence = ""
	if opened:
		var direction := Vector2(float(Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_UP))).normalized()
		full_map.center_world += direction*260.0*delta/full_map.zoom
		full_map.center_world = full_map.center_world.clamp(Vector2.ZERO,Vector2(Layout.SIZE))
		full_map.zoom = lerpf(full_map.zoom,target_zoom,1.0-exp(-14.0*delta))
	elif normal_exploration() and sequence.is_empty():
		var current := Vector2i(world.player.position/64.0)
		if current != last_reveal_cell or last_area != Session.area_id:
			last_reveal_cell = current
			last_area = Session.area_id
			update_exploration()
	_refresh()

func _refresh() -> void:
	var point := Layout.world_point(Session.area_id,world.player.position)
	minimap.center_world = point
	minimap.player_world = point
	full_map.player_world = point
	minimap.facing = world.player.facing_direction
	full_map.facing = world.player.facing_direction
	minimap.visible = normal_exploration() and not modal_open()
	if minimap.visible: minimap.refresh(Session.map_reveal_cheat)
	if opened: full_map.refresh(Session.map_reveal_cheat)
