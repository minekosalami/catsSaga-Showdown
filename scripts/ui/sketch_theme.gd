extends RefCounted

const PAPER := Color("#eeeae2")
const INK := Color("#18181b")
const MUTED := Color("#92908c")
const ACCENT := Color("#e28bcb")

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
	result.default_font_size = 16
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_shadow_color", "Label", INK)
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 1)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := INK
		var edge := MUTED
		if state == "hover" or state == "pressed":
			fill = PAPER
			edge = PAPER
		if state == "focus":
			fill = Color.TRANSPARENT
			edge = ACCENT
		result.set_stylebox(state, "Button", box(fill, edge, 2 if state == "focus" else 1))
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_focus_color", "Button", PAPER)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_stylebox("panel", "PanelContainer", box(Color("#18181bf0"), MUTED))
	var track := box(Color("#37373b"), MUTED)
	var fill := box(PAPER, PAPER, 0)
	track.set_content_margin_all(0)
	fill.set_content_margin_all(0)
	result.set_stylebox("background", "ProgressBar", track)
	result.set_stylebox("fill", "ProgressBar", fill)
	return result
