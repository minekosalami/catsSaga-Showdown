extends RefCounted

const Sketch := preload("res://scripts/ui/sketch_theme.gd")
const INK := Color("#10111C")
const EDGE := Color("#776A91")
const BLUE := Color("#81D8ED")
const PAPER := Color("#F4F0E7")

static func theme() -> Theme:
	var result := Sketch.create()
	result.set_stylebox("panel","PanelContainer",card())
	return result

static func card() -> StyleBoxFlat:
	var box := Sketch.box(Color(INK,0.96),Color("#655A77"))
	box.set_content_margin_all(8)
	box.border_width_left = 3
	box.border_width_right = 1
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 0
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
