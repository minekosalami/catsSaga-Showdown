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
	return preload("res://scripts/ui/presentation/style.gd").box(Color(INK,.96),preload("res://scripts/ui/presentation/style.gd").MINT,1,8)

static func progress(bar: ProgressBar, tint: Color = BLUE) -> void:
	if "tint" in bar:bar.tint=tint
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := Sketch.box(Color("#27333E"),Color("#354651"),0)
	track.set_content_margin_all(0)
	var fill := Sketch.box(tint,tint,0)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background",track)
	bar.add_theme_stylebox_override("fill",fill)
