extends RefCounted

const PAPER := Color("#f4f0e7")
const INK := Color("#101115")
const MUTED := Color("#999890")
const ACCENT := Color("#e498bc")

const UI_FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
const TITLE_FONT = UI_FONT

static func box(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_content_margin_all(12)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 3
	return style

static func create() -> Theme:
	return preload("res://scripts/ui/presentation/style.gd").theme()
