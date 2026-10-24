extends CanvasLayer
var world: Node
var root: Control
var keeper: TextureRect
var merchandise: TextureRect
var price: Label
var close_button: Button
var animating := false
var keeper_home := Vector2.ZERO

func _ready() -> void:
	layer=9
	root=Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme=preload("res://scripts/ui/sketch_theme.gd").create()
	var wall:=NinePatchRect.new()
	wall.texture=preload("res://scripts/story/assets.gd").RPG
	wall.region_rect=Rect2(17*27,17*14,16,16)
	wall.axis_stretch_horizontal=NinePatchRect.AXIS_STRETCH_MODE_TILE
	wall.axis_stretch_vertical=NinePatchRect.AXIS_STRETCH_MODE_TILE
	wall.modulate=Color(.65,.60,.55)
	wall.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(wall)
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keeper=_picture(preload("res://assets/npc textures/SHOPKEEPER (1).png"),Rect2(.08,.06,.34,.40))
	merchandise=_picture(preload("res://assets/npc textures/wand.png"),Rect2(.65,.16,.16,.28))
	price=Label.new()
	price.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(price)
	price.anchor_left=.5;price.anchor_right=.97;price.anchor_top=.47;price.anchor_bottom=.55
	price.add_theme_font_size_override("font_size",18)
	price.add_theme_color_override("font_outline_color",Color.BLACK)
	price.add_theme_constant_override("outline_size",5)
	close_button=Button.new()
	close_button.text="Close"
	root.add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left=-140;close_button.offset_top=20;close_button.offset_right=-24;close_button.offset_bottom=64
	close_button.pressed.connect(close)
	world.dialogue.finished.connect(_finished)
	Session.story_progress.changed.connect(_refresh)
	_refresh()
	world.hide_interaction()
	world.player.movement_locked=true
	welcome()
func _picture(texture: Texture2D, anchors: Rect2) -> TextureRect:
	var rect:=TextureRect.new()
	rect.texture=texture
	rect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(rect)
	rect.anchor_left=anchors.position.x;rect.anchor_top=anchors.position.y
	rect.anchor_right=anchors.end.x;rect.anchor_bottom=anchors.end.y
	return rect
func _refresh() -> void:
	merchandise.visible=not Session.story_progress.wand_acquired
	price.text="Cupid's Wand — 9,999 NeCoins" if merchandise.visible else "Cupid's Wand — Acquired"
func _graph(lines: Array, options: Array, speaker := "SHOPKEEPER") -> void:
	world.dialogue.start_graph({"start":"shop","nodes":{"shop":{"speaker":speaker,"lines":lines,"choices":options}}})
func welcome() -> void:
	_graph(["Welcome to the PAWn shop! Where one cat's trash is another cat's treasure!"],[{"text":"BUY","end":"shop_buy"},{"text":"TALK","end":"shop_talk"}])
func _finished() -> void:
	match world.dialogue.outcome:
		"shop_buy":
			if Session.story_progress.wand_acquired:welcome.call_deferred()
			else: _graph.call_deferred(["Cupid's Wand — 9,999 NeCoins"],[{"text":"BUY","end":"shop_purchase"},{"text":"Back","end":"shop_welcome"}],"")
		"shop_purchase":
			if not Session.story_progress.acquire_wand(true):Session.show_notification("Insufficient NeCoins.")
			welcome.call_deferred()
		"shop_talk":_graph.call_deferred(["Welcome to the PAWn shop! Where one cat's trash is another cat's treasure!"],[{"text":"JOKE","end":"shop_joke"},{"text":"DISTRACT","end":"shop_distract"}])
		"shop_joke":
			world.dialogue.start_graph.call_deferred({"start":"joke","nodes":{"joke":{"speaker":"SHOPKEEPER","lines":["Where does the cat go when he loses his tail??","The reTAIL store!!!! MEOWHEHEHEHEHEHEhehehehehe...."],"end":"shop_welcome"}}})
		"shop_distract":
			world.dialogue.start_graph.call_deferred({"start":"player","nodes":{"player":{"speaker":"PLAYER","lines":["Is that a flying CAT TREAT?? Quick, look!"],"next":"keeper"},"keeper":{"speaker":"SHOPKEEPER","lines":["Where!?"],"end":"shop_run"}}})
		"shop_run":_run_away.call_deferred()
		"shop_steal":
			Session.story_progress.acquire_wand(false)
			_return_keeper.call_deferred()
		"shop_leave_wand":_return_keeper.call_deferred()
		"shop_welcome":welcome.call_deferred()
func _run_away() -> void:
	animating=true
	close_button.disabled=true
	keeper_home=keeper.position
	await create_tween().tween_property(keeper,"position:x",-keeper.size.x-32,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).finished
	if Session.story_progress.wand_acquired:
		await _return_keeper()
	else:
		_graph(["STEAL expensive wand?"],[{"text":"Yes","end":"shop_steal"},{"text":"No","end":"shop_leave_wand"}],"")
func _return_keeper() -> void:
	await create_tween().tween_property(keeper,"position",keeper_home,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).finished
	animating=false
	close_button.disabled=false
	# No additional shopkeeper dialogue after returning.
	_graph(["BUY / TALK"],[{"text":"BUY","end":"shop_buy"},{"text":"TALK","end":"shop_talk"}],"")
func close() -> void:
	if animating:return
	world.dialogue.finished.disconnect(_finished)
	if world.dialogue.active:world.dialogue._finish("")
	world.story_shop=null
	queue_free()

func _input(event: InputEvent) -> void:
	if not event.is_echo() and (event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
