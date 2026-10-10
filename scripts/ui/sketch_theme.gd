extends RefCounted

const PAPER := Color("#f4f0e7")
const INK := Color("#101115")
const MUTED := Color("#999890")
const ACCENT := Color("#e498bc")

const TITLE_FONT = preload("res://assets/ui/fonts/DejaVuSerifCondensed.ttf")
const UI_FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")

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
	var result := Theme.new()
	result.default_font = UI_FONT
	result.default_font_size = 16
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_shadow_color", "Label", INK)
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 1)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color.TRANSPARENT
		var edge := Color.TRANSPARENT
		if state == "hover" or state == "pressed":
			fill = INK
			edge = INK
		if state == "focus":
			fill = Color.TRANSPARENT
			edge = ACCENT
		result.set_stylebox(state, "Button", box(fill, edge, 2 if state == "focus" else 1))
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", PAPER)
	result.set_color("font_pressed_color", "Button", PAPER)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_stylebox("panel", "PanelContainer", box(Color("#18181bf0"), MUTED))
	var track := box(Color("#37373b"), MUTED)
	var fill := box(PAPER, PAPER, 0)
	track.set_content_margin_all(0)
	fill.set_content_margin_all(0)
	result.set_stylebox("background", "ProgressBar", track)
	result.set_stylebox("fill", "ProgressBar", fill)
	return result
