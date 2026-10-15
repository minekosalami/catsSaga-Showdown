extends "res://scripts/world/area.gd"
const Blueprint = preload("res://scripts/world/cave_layout.gd")
var current_room := 1
var room_image: Image
var room_mask: ShaderMaterial
var screen_filter: ShaderMaterial
var screen_layer: CanvasLayer
var intro_started := false
var drone: AudioStreamPlayer
var gray := 0.0
var boss: Node2D
var host: Node
var services: CanvasLayer
func is_walkable_position(point: Vector2) -> bool:
	var cell: Vector2i = $CaveFloor.local_to_map(point/$CaveFloor.scale)
	return $CaveFloor.get_cell_source_id(cell) >= 0 and $CaveWater.get_cell_source_id(cell) < 0 and cell_room(cell).x != 10
func cell_room(cell: Vector2i) -> Vector2i:
	if room_image == null: room_image = load("res://resources/cave/room_ids.res").get_image()
	if cell.x < 0 or cell.y < 0 or cell.x >= room_image.get_width() or cell.y >= room_image.get_height(): return Vector2i.ZERO
	var color := room_image.get_pixelv(cell)
	return Vector2i(roundi(color.r*255),roundi(color.g*255))
func panel(layer: int, shader: Shader) -> ShaderMaterial:
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	add_child(canvas)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	if layer == 128: screen_layer = canvas
	return material
func _ready():
	host = get_parent()
	room_image = load("res://resources/cave/room_ids.res").get_image()
	room_mask = panel(1,preload("res://shaders/cave_room_mask.gdshader"))
	room_mask.set_shader_parameter("rooms",load("res://resources/cave/room_ids.res"))
	room_mask.set_shader_parameter("map_size",map_size)
	room_mask.set_shader_parameter("rock",load(preload("res://scripts/world/cave_assets.gd").PACK+"tiles/wall-tiles-32x32.png"))
	room_mask.set_shader_parameter("window_rect",Vector4(Blueprint.WINDOW.position.x,Blueprint.WINDOW.position.y,Blueprint.WINDOW.size.x,Blueprint.WINDOW.size.y))
	RenderingServer.frame_pre_draw.connect(_update_mask)
	screen_filter = panel(128,preload("res://shaders/cave_desaturation.gdshader"))
	Session.story_flags["cave_redesign_layout_v2"] = true
	Session.story_flags["cave_settlement_layout_v3"] = true
	services = CanvasLayer.new()
	services.set_script(preload("res://scripts/world/cave_services.gd"))
	add_child(services)
	drone = AudioStreamPlayer.new()
	drone.stream = $UndergroundAtmosphere.sound("bed")
	drone.pitch_scale = .45
	drone.volume_db = -60
	drone.bus = "Overworld"
	add_child(drone)
	boss = preload("res://scripts/incarna/rig.gd").new()
	boss.name = "Incarna"
	boss.preview_mode = true
	boss.scale = Vector2.ONE*.12
	boss.position = Blueprint.center(8)
	add_child(boss)
	var label := Label.new()
	label.text = "INCARNA()"
	label.name = "Boss4Label"
	label.position = boss.position+Vector2(-88,-85)
	label.add_theme_font_size_override("font_size",14)
	add_child(label)
	if Session.story_flags.get("incarna_defeated",false):
		boss.hide()
		label.hide()
	var chest := preload("res://scripts/wonderland/reward_chest.gd").new()
	chest.name = "IncarnaWonderlandChest"
	chest.position = preload("res://scripts/wonderland/layout.gd").CHEST
	add_child(chest)
func _process(delta: float):
	if not is_instance_valid(host) or host.get_node_or_null("Explorer") == null: return
	var point: Vector2 = host.player.position
	var ids := cell_room(Vector2i(point/32))
	if ids.x != 0:
		if ids.y == 0: current_room = ids.x
		elif current_room not in [ids.x,ids.y]: current_room = ids.x
	var in_quiet_room: bool = ids == Vector2i(7,0) and $CaveFloor.get_cell_source_id(Vector2i(point/32)) >= 0
	var gray_target := 1.0 if in_quiet_room else 0.0
	gray = move_toward(gray,gray_target,delta) if in_quiet_room else 0.0
	screen_filter.set_shader_parameter("amount",gray)
	screen_layer.visible = gray > 0
	if in_quiet_room:
		if not drone.playing: drone.play()
		drone.volume_db = lerpf(-60,-27,gray)
	else:
		drone.stop()
	var ambience: Node = $UndergroundAtmosphere
	if not Session.busy and not ambience.fade_started:
		ambience.bed.volume_db = -28-28*gray
		ambience.drip.volume_db = -28-28*gray
		ambience.echo.volume_db = -32-28*gray
	if current_room == 9 and not intro_started and not Session.story_flags.get("incarna_defeated",false) and not Session.busy and not host.checking_spawn and not Session.cave_event_active:
		begin_intro()
func _update_mask():
	if not is_instance_valid(host) or host.get_node_or_null("Explorer") == null: return
	var inverse := global_transform.affine_inverse()*get_viewport().get_canvas_transform().affine_inverse()
	var size: Vector2 = host.get_viewport_rect().size
	room_mask.set_shader_parameter("top_left",inverse*Vector2.ZERO)
	room_mask.set_shader_parameter("axis_x",inverse.basis_xform(Vector2(size.x,0)))
	room_mask.set_shader_parameter("axis_y",inverse.basis_xform(Vector2(0,size.y)))
	room_mask.set_shader_parameter("player_position",to_local(host.player.global_position))
	room_mask.set_shader_parameter("active_room",float(current_room))
	room_mask.set_shader_parameter("clock",$UndergroundAtmosphere.clock)
func use_shortcut(to_junction: bool):
	Session.cave_event_active = true
	host.player.velocity = Vector2.ZERO
	Session.curtain.show()
	Session.curtain.modulate.a = 0
	var fade := create_tween()
	fade.tween_property(Session.curtain,"modulate:a",1.0,.18)
	await fade.finished
	host.player.position = (Blueprint.SHORTCUT_JUNCTION if to_junction else Blueprint.SHORTCUT_HUB)+Vector2(0,90)
	current_room = 8 if to_junction else 4
	var camera: Camera2D = host.player.get_node("Camera2D")
	camera.reset_smoothing()
	camera.force_update_scroll()
	fade = create_tween()
	fade.tween_property(Session.curtain,"modulate:a",0.0,.18)
	await fade.finished
	Session.curtain.hide()
	Session.cave_event_active = false
	Session.save_current()
func begin_intro():
	intro_started = true
	Session.cave_event_active = true
	host.hide_interaction()
	host.player.velocity = Vector2.ZERO
	var camera: Camera2D = host.player.get_node("Camera2D")
	var view: Vector2 = host.get_viewport_rect().size/camera.zoom
	var before: Vector2 = host.player.position
	# Keep the reward alcove physically beyond the cave apparition at wider views.
	var reward_x: float = preload("res://scripts/wonderland/layout.gd").CHEST.x
	boss.position = Vector2(minf(before.x+view.x*.82,reward_x-256),before.y)
	$Boss4Label.position = boss.position+Vector2(-88,-85)
	var target := (before+boss.position)*.5
	camera.position_smoothing_enabled = false
	camera.limit_enabled = false
	var move := create_tween()
	move.tween_property(camera,"global_position",target,1.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await move.finished
	camera.force_update_scroll()
	host.dialogue.start_lines([{"speaker":"Incarna","text":"Welcome to the underground."}])
	await host.dialogue.finished
	Session.cave_event_active = false
	Session.return_position = Blueprint.SHORTCUT_JUNCTION+Vector2(0,160)
	Session.encounter_id = "incarna"
	Session.encounter_active = true
	await Session.transition_to("res://scenes/incarna/combat_host.tscn",true)
func modal_open() -> bool: return services != null and services.opened
func _exit_tree():
	Session.cave_event_active = false
	if RenderingServer.frame_pre_draw.is_connected(_update_mask): RenderingServer.frame_pre_draw.disconnect(_update_mask)
