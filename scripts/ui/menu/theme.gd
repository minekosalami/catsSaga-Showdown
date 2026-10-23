extends RefCounted
const FONT = preload("res://assets/ui/fonts/DejaVuSansMono.ttf")
static func box(fill: Color,edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(14)
	return style
static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font=FONT
	theme.default_font_size=17
	for type in ["Label","Button","CheckButton","OptionButton","TabContainer"]:
		theme.set_color("font_color",type,Color("#eee5fc"))
		theme.set_color("font_hover_color",type,Color.WHITE)
		theme.set_color("font_focus_color",type,Color.WHITE)
		theme.set_color("font_disabled_color",type,Color("#8d7d9d"))
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,box(Color("#21132ef5"),Color("#725282")))
		theme.set_stylebox("hover",type,box(Color("#49305c"),Color("#da9dd9")))
		theme.set_stylebox("pressed",type,box(Color("#593866"),Color("#f4b6e8")))
		theme.set_stylebox("disabled",type,box(Color("#1a1423"),Color("#42334e")))
		var focus := box(Color.TRANSPARENT,Color("#e6b6ff"))
		focus.set_border_width_all(2)
		theme.set_stylebox("focus",type,focus)
	for type in ["PanelContainer","PopupMenu","AcceptDialog"]:theme.set_stylebox("panel",type,box(Color("#180f24fa"),Color("#876291")))
	theme.set_stylebox("panel","TabContainer",box(Color("#1c1329"),Color("#594064")))
	for state in ["tab_selected","tab_unselected","tab_hovered"]:
		theme.set_stylebox(state,"TabBar",box(Color("#49305c" if state=="tab_selected" else "#24182f"),Color("#876291")))
	var border := box(Color("#281834"),Color("#876291"))
	border.content_margin_top=30
	theme.set_stylebox("embedded_border","Window",border)
	theme.set_stylebox("embedded_unfocused_border","Window",border)
	return theme
static func button(parent: Node,text: String,action: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(360,52)
	button.pressed.connect(action)
	button.mouse_entered.connect(func():if not button.disabled:button.grab_focus())
	parent.add_child(button)
	return button
