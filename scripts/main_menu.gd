extends Control
const Art=preload("res://scripts/ui/presentation/style.gd")
const Style = preload("res://scripts/ui/menu/theme.gd")
var menu_container: VBoxContainer
var title_label: Label
var page: VBoxContainer
var center: CenterContainer
var status: Label
var transitioning := false
var page_kind := ""
var hero: Control
var menu_surface: PanelContainer

func _ready() -> void:
	theme=Style.create()
	var background:=ColorRect.new();background.name="Background";background.set_script(preload("res://scripts/ui/menu/background.gd"))
	add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero=preload("res://scripts/ui/presentation/menu_hero.gd").new();add_child(hero)
	hero.position=Vector2(58,22);hero.size=Vector2(520,650)
	var brand:=VBoxContainer.new();hero.add_child(brand);brand.position=Vector2(35,58)
	heading(brand,"catsSaga()",65).add_theme_font_override("font",Art.DISPLAY)
	title_label=brand.get_child(0)
	var edition:=heading(brand,"SHOWDOWN  /  EXPLORE  /  RECORDS",12);edition.add_theme_color_override("font_color",Art.MINT)
	center=CenterContainer.new();center.name="CenterContainer";add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.anchor_left=.51
	menu_surface=preload("res://scripts/ui/presentation/surface.gd").new();center.add_child(menu_surface)
	menu_container=VBoxContainer.new();menu_container.name="Menu";menu_container.custom_minimum_size.x=390
	menu_container.add_theme_constant_override("separation",10);menu_surface.add_child(menu_container)
	var caption:=heading(menu_container,"// MAIN MENU",13);caption.add_theme_color_override("font_color",Art.MINT)
	for item in [["Continue","ContinueButton",_continue_game],["New Game","NewGameButton",_start_game],["Settings","SettingsButton",Session.open_options],["Records","RecordsButton",_show_records],["Credits","CreditsButton",_show_credits],["Quit","QuitButton",_quit_game]]:
		var b:=Style.button(menu_container,item[0],item[2]);b.name=item[1]
	menu_container.get_node("ContinueButton").disabled=Session.saves.most_recent_slot()==0
	status=Label.new();status.custom_minimum_size=Vector2(380,28);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12)
	status.text=Session.migration_message;Session.migration_message="";menu_container.add_child(status)
	_fade(menu_surface)
	menu_container.get_node("NewGameButton" if Session.saves.most_recent_slot()==0 else "ContinueButton").grab_focus()

func heading(parent: Node,text: String,size: int=26) -> Label:
	var label := Label.new()
	label.text=text
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label
func _fade(control: Control) -> void:
	control.modulate.a=0
	create_tween().tween_property(control,"modulate:a",1.0,.24)
func _new_page(kind: String,title: String) -> void:
	if is_instance_valid(page):
		page.hide()
		page.queue_free()
	page_kind=kind
	menu_container.hide()
	menu_surface.hide();hero.hide();center.anchor_left=0
	page=VBoxContainer.new()
	page.custom_minimum_size.x=880 if kind=="records" else 620
	page.add_theme_constant_override("separation",14)
	center.add_child(page)
	heading(page,title)
	_fade(page)
func _start_game() -> void:
	if transitioning or Session.busy:return
	_new_page("slots","New Game")
	for slot in range(1,4):
		var data: Dictionary=Session.saves.read_slot(slot)
		var description := "Empty" if not Session.saves.slot_exists(slot) else "Unreadable — original retained until confirmed replacement"
		if not data.is_empty():description="%s · %02d:%02d"%[data.area.replace("_"," ").capitalize(),int(data.playtime)/3600,int(data.playtime)/60%60]
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation",6)
		page.add_child(line)
		var caption := heading(line,"Slot %d — %s"%[slot,description],14)
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var actions := HBoxContainer.new()
		line.add_child(actions)
		var button := Style.button(actions,"New Game",_select_new_slot.bind(slot))
		button.custom_minimum_size=Vector2(220,44)
		var load_button := Style.button(actions,"Load",_load_slot.bind(slot))
		load_button.custom_minimum_size=Vector2(220,44)
		load_button.disabled=data.is_empty()
		if slot==1:button.grab_focus()
	var hint := heading(page,"Save progress at save stars.\nEarned progress saves automatically; save stars set your checkpoint.",13)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	Style.button(page,"Back",go_back)
func _select_new_slot(slot: int) -> void:
	if Session.saves.slot_exists(slot):
		Session.confirm_action("Start a new game in Slot %d? This replaces its earned progress and checkpoint."%slot,_begin_new_game.bind(slot))
	else:_begin_new_game(slot)
func _begin_new_game(slot: int=1) -> void:
	if transitioning or Session.busy:return
	transitioning=true
	Session.new_game(slot)
func _continue_game() -> void:
	_load_slot(Session.saves.most_recent_slot())
func _load_slot(slot: int) -> void:
	if transitioning or Session.busy:return
	if Session.saves.read_slot(slot).is_empty():
		status.text="No valid save. No new game was started."
		Session.show_notification(status.text)
		return
	transitioning=true
	Session.load_game(slot)
func _show_records() -> void:
	_new_page("records","Showdown Records")
	Session.records.load_records()
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(900,460);page.add_child(scroll)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",8);scroll.add_child(rows)
	var names: Dictionary=preload("res://scripts/rpg/records.gd").NAMES.duplicate()
	for id in Session.records.best:
		if not names.has(id):names[id]=id.capitalize()
	for id in names:
		var value: float=Session.records.best.get(id,-1.0)
		var grade:=preload("res://scripts/rpg/score.gd").grade(value) if value>=0 else "—"
		var row:=PanelContainer.new();rows.add_child(row)
		row.add_theme_stylebox_override("panel",Art.box(Art.INK,Art.grade_color(grade),1,10))
		row.focus_mode=Control.FOCUS_ALL
		row.mouse_entered.connect(row.grab_focus)
		row.focus_entered.connect(func():
			row.add_theme_stylebox_override("panel",Art.box(Color("#233a51"),Art.MINT,2,10))
			scroll.ensure_control_visible(row))
		row.focus_exited.connect(func():row.add_theme_stylebox_override("panel",Art.box(Art.INK,Art.grade_color(grade),1,10)))
		var line:=HBoxContainer.new();line.add_theme_constant_override("separation",20);row.add_child(line)
		var picture:=TextureRect.new();picture.texture=preload("res://scripts/ui/presentation/portraits.gd").texture(id)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		picture.custom_minimum_size=Vector2(58,52);line.add_child(picture)
		preload("res://scripts/ui/presentation/portraits.gd").prepare(picture,id)
		var name_label:=Art.label(line,names[id],19);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		Art.label(line,"Not defeated" if value<0 else preload("res://scripts/rpg/score.gd").display(value),20,Art.MUTED if value<0 else Art.PAPER)
		var rank:=Art.label(line,grade,30,Art.grade_color(grade));rank.custom_minimum_size.x=72;rank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rank.add_theme_font_override("font",Art.BOLD)
	Style.button(page,"Back",go_back).grab_focus()
func _show_credits() -> void:
	_new_page("credits","Credits")
	var text := RichTextLabel.new()
	text.custom_minimum_size=Vector2(600,360)
	text.selection_enabled=true
	text.add_theme_font_size_override("normal_font_size",15)
	text.text="LLiosette — Creator\n\n"+preload("res://resources/ui/wonderland_asset_notices.tres").get_meta("text")+"\n\nBasic Caves & Dungeons — schwarnhild\nhttps://schwarnhild.itch.io\n\nDejaVu fonts — DejaVu contributors / Bitstream Vera license.\nFull font license: assets/ui/fonts/LICENSE.txt"
	text.text+="\n\n"+preload("res://resources/ui/environment_asset_notices.tres").get_meta("text")
	text.text+="\n\n"+preload("res://resources/ui/weather_asset_notices.tres").get_meta("text")
	page.add_child(text)
	Style.button(page,"Back",go_back).grab_focus()
func go_back() -> bool:
	if page_kind.is_empty():return false
	var kind := page_kind
	page_kind=""
	page.hide()
	page.queue_free()
	menu_container.show()
	menu_surface.show();hero.show();center.anchor_left=.51
	menu_container.get_node("CreditsButton" if kind=="credits" else ("RecordsButton" if kind=="records" else "NewGameButton")).grab_focus()
	_fade(menu_container)
	return true
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and go_back():get_viewport().set_input_as_handled()
func _quit_game() -> void:
	Session.persist_progress()
	get_tree().quit()
