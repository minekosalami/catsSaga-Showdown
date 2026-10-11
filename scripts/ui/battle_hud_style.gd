extends RefCounted

const Sketch := preload("res://scripts/ui/sketch_theme.gd")
const INK := Color("#10161D")
const EDGE := Color("#586875")
const BLUE := Color("#81D8ED")
const PAPER := Color("#F4F0E7")

static func theme() -> Theme:
	var result := Sketch.create()
	result.set_stylebox("panel","PanelContainer",card())
	return result

static func card() -> StyleBoxFlat:
	var box := Sketch.box(Color(INK,0.94),EDGE)
	box.set_content_margin_all(8)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	return box

static func progress(bar: ProgressBar, tint: Color = BLUE) -> void:
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := Sketch.box(Color("#27333E"),Color("#354651"),0)
	track.set_content_margin_all(0)
	var fill := Sketch.box(tint,tint,0)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background",track)
	bar.add_theme_stylebox_override("fill",fill)
