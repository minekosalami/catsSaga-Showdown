extends RefCounted
const Art=preload("res://scripts/ui/presentation/style.gd")
const FONT=Art.FONT
static func box(fill: Color, edge: Color) -> StyleBoxFlat:return Art.box(fill,edge)
static func create() -> Theme:return Art.theme()
static func button(parent: Node,text: String,action: Callable) -> Button:
	var button:=preload("res://scripts/ui/presentation/button.gd").new()
	button.text=text;button.custom_minimum_size=Vector2(360,52)
	button.pressed.connect(action)
	button.mouse_entered.connect(func():if not button.disabled:button.grab_focus())
	parent.add_child(button)
	return button
