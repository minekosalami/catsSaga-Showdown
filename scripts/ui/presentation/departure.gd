extends RefCounted
const Style=preload("res://scripts/ui/presentation/style.gd")
static func decorate(curtain: Control, source: Node) -> void:
	var caption:=curtain.get_node_or_null("DepartureCaption") as Label
	if caption==null:
		caption=Label.new();caption.name="DepartureCaption";curtain.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_override("font",Style.BOLD);caption.add_theme_font_size_override("font_size",26)
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.hide()
	if source==null or not "battle" in source or not is_instance_valid(source.battle):return
	var battle: Node=source.battle
	if battle.game_over:
		caption.text="SHOWDOWN / DEFEAT\nReturning to checkpoint";caption.modulate=Style.CORAL
	elif "settled" in battle and battle.settled and not source.rpg_ui.done:
		caption.text="FLEE / ESCAPED\nReturning to overworld";caption.modulate=Style.MINT
	elif battle.victory_started:
		caption.text="SHOWDOWN / COMPLETE";caption.modulate=Style.GOLD
	else:return
	caption.show()
