extends CanvasLayer
var world: Node
var root: Control
var keeper: TextureRect
var merchandise: TextureRect
var price: Label
var close_button: Button
var animating := false
var keeper_home := Vector2.ZERO
var balance_label: Label
var last_balance := -1
var styled_choices: Array=[]

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
	wall.modulate=Color(.25,.36,.42)
	wall.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(wall)
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ambient:=preload("res://scripts/ui/presentation/ambient.gd").new()
	root.add_child(ambient);ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading:=preload("res://scripts/ui/presentation/style.gd").label(root,"PAWn SHOP",30,Color("#ffda7e"))
	heading.position=Vector2(36,22)
	balance_label=preload("res://scripts/ui/presentation/style.gd").label(root,"",21,Color("#ffda7e"))
	balance_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	balance_label.anchor_left=.44;balance_label.anchor_right=.64
	balance_label.offset_left=0;balance_label.offset_right=0;balance_label.offset_top=28
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
func _process(_delta: float) -> void:
	if last_balance!=Session.story_progress.necoins:
		var increased:=last_balance>=0
		last_balance=Session.story_progress.necoins
		balance_label.text="%d NeCoins"%last_balance
		if increased:
			preload("res://scripts/ui/presentation/style.gd").pop(balance_label,1.1)
			preload("res://scripts/ui/presentation/style.gd").burst(root,balance_label.position+Vector2(70,18),Color("#ffda7e"),14)
	# Style existing choice buttons; no second purchase menu or input handler.
	for i in world.dialogue.choice_buttons.size():
		var button: Button=world.dialogue.choice_buttons[i]
		if button.get_instance_id() in styled_choices:continue
		styled_choices.append(button.get_instance_id())
		if i<world.dialogue.choices.size() and world.dialogue.choices[i].get("end","").begins_with("shop_item_"):
			button.add_theme_stylebox_override("normal",preload("res://scripts/ui/presentation/style.gd").box(Color("#1b3044"),Color("#74e7cf")))
			button.custom_minimum_size.y=58
			var id: String=world.dialogue.choices[i].end.trim_prefix("shop_item_")
			var description:=preload("res://scripts/ui/presentation/style.gd").label(button,Session.rpg.ITEMS[id].effect,11,Color("#9aaac2"))
			description.mouse_filter=Control.MOUSE_FILTER_IGNORE;description.position=Vector2(48,34)
	# Free stale references when dialogue pages replace their button nodes.
	if world.dialogue.choice_buttons.is_empty():styled_choices.clear()
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
	world.dialogue.text_label.custom_minimum_size.y=28 if options.any(func(option):return option.get("end","").begins_with("shop_item_")) else 80
func welcome() -> void:
	_buy_layout(false)
	_graph(["Welcome to the PAWn shop! Where one cat's trash is another cat's treasure!"],[{"text":"BUY","end":"shop_buy"},{"text":"TALK","end":"shop_talk"}])
func _buy_layout(enabled: bool) -> void:
	# Keep the unchanged portraits and wand above the expanded item-choice list.
	keeper.anchor_bottom=.31 if enabled else .46
	merchandise.anchor_top=.04 if enabled else .16
	merchandise.anchor_bottom=.28 if enabled else .44
	price.anchor_top=.29 if enabled else .47
	price.anchor_bottom=.33 if enabled else .55
func buy_menu() -> void:
	_buy_layout(true)
	var options: Array=[]
	if not Session.story_progress.wand_acquired:options.append({"text":"Cupid's Wand — 9,999 NeCoins","end":"shop_purchase"})
	for id in Session.rpg.ITEMS:
		var item: Dictionary=Session.rpg.ITEMS[id]
		options.append({"text":"%s — %d NeCoins (×%d)"%[item.name,item.price,Session.rpg.inventory[id]],"end":"shop_item_"+id})
	options.append({"text":"Back","end":"shop_welcome"})
	_graph(["BUY"],options,"")
func _finished() -> void:
	if world.dialogue.outcome.begins_with("shop_item_"):
		var id: String=world.dialogue.outcome.trim_prefix("shop_item_")
		if not Session.rpg.purchase(id,Session.story_progress):Session.show_notification("Insufficient NeCoins.")
		else:Session.show_notification(Session.rpg.ITEMS[id].name+" purchased.","PurchaseNotification")
		buy_menu.call_deferred()
		return
	match world.dialogue.outcome:
		"shop_buy":
			buy_menu.call_deferred()
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
