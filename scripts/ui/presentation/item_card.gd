extends Button
const Style=preload("res://scripts/ui/presentation/style.gd")
var item_id:=""
var title: Label
var amount: Label
var detail: Label
var active_selection:=false
var blend:=0.0
var accent:=Style.CORAL
var previous_quantity:=-1
func _ready() -> void:
	custom_minimum_size.y=106
	focus_mode=Control.FOCUS_NONE
	accent={"first_aid":Style.CORAL,"cat_treats":Style.GOLD,"shield_ring":Style.MINT}.get(item_id,Style.LILAC)
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left=62;row.offset_right=-16;row.offset_top=12;row.offset_bottom=-10
	var column:=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(column)
	title=Style.label(column,"",18);title.add_theme_font_override("font",Style.BOLD)
	detail=Style.label(column,"",12,Style.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	amount=Style.label(row,"",24,accent)
	for child in [title,amount,detail]:child.mouse_filter=Control.MOUSE_FILTER_IGNORE
func update_item(name_text: String, effect: String, quantity: int, chosen: bool) -> void:
	title.text=name_text;detail.text=effect;amount.text="×%d"%quantity;active_selection=chosen
	if previous_quantity>=0 and previous_quantity!=quantity:Style.pop(amount,1.25)
	previous_quantity=quantity
func _process(delta: float) -> void:
	blend=lerpf(blend,1.0 if active_selection else 0.0,1-exp(-delta*16))
	queue_redraw()
func _draw() -> void:
	var alpha:=.5 if disabled else 1.0
	draw_rect(Rect2(0,8,3,size.y-16),Color(accent,alpha*(.35+.65*blend)))
	draw_circle(Vector2(31,size.y*.5),18,Color(accent,.12+.10*blend))
	# Functional item emblems use permitted UI geometry, not image artwork.
	var center:=Vector2(31,size.y*.5)
	if item_id=="first_aid":
		draw_rect(Rect2(center-Vector2(3,11),Vector2(6,22)),Color(accent,alpha))
		draw_rect(Rect2(center-Vector2(11,3),Vector2(22,6)),Color(accent,alpha))
	elif item_id=="cat_treats":
		for p in [Vector2(-5,-5),Vector2(5,-5),Vector2(0,5)]:draw_circle(center+p,4,Color(accent,alpha))
	else:draw_arc(center,11,-PI*.7,PI*1.3,24,Color(accent,alpha),3)
	if blend>.01:draw_line(Vector2(9,size.y-5),Vector2(9+(size.x-18)*blend,size.y-5),Color(accent,.5),2)
func feedback(success: bool) -> void:
	Style.pop(self,1.025 if success else .98)
	if success:Style.burst(self,Vector2(size.x-30,size.y*.5),accent,12)
	else:
		modulate=Style.CORAL
		create_tween().tween_property(self,"modulate",Color.WHITE,.25)
