extends Control

const Layout = preload("res://scripts/maps/world_layout.gd")
const FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
var map_area := "entrance"
var center_world := Vector2.ZERO
var player_world := Vector2.ZERO
var facing := Vector2.LEFT
var zoom := 2.5
var circular := false
var shader: ShaderMaterial
var last_state: Array = []
var boss_markers: Array = []

func configure(terrain: Texture2D, fog: Texture2D, circle: bool, area: String = "entrance") -> void:
	map_area = area
	circular = circle
	shader = ShaderMaterial.new()
	shader.shader = preload("res://resources/maps/cartography.gdshader")
	shader.set_shader_parameter("terrain",terrain)
	shader.set_shader_parameter("atlas_size",terrain.get_size())
	shader.set_shader_parameter("explored",fog)
	shader.set_shader_parameter("circular",circle)
	material = shader
	# Overlay strokes need their own unshaded canvas item, outside the terrain shader.
	var ink := Control.new()
	ink.name = "Ink"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.set_script(preload("res://scripts/maps/map_ink.gd"))
	add_child(ink)
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func refresh(reveal: bool) -> void:
	var state := [center_world,player_world,facing,zoom,size,reveal,boss_markers.duplicate(true)]
	if state == last_state: return
	last_state = state
	shader.set_shader_parameter("center_world",center_world)
	shader.set_shader_parameter("canvas_size",size)
	shader.set_shader_parameter("map_zoom",zoom)
	shader.set_shader_parameter("reveal_all",reveal)
	queue_redraw()
	$Ink.queue_redraw()

func screen_point(point: Vector2) -> Vector2:
	return (point-center_world)*zoom+size/2

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
