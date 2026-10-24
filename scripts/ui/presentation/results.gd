extends PanelContainer
const Style=preload("res://scripts/ui/presentation/style.gd")
const Score=preload("res://scripts/rpg/score.gd")
signal advanced
var data: Dictionary
var grade: Label
var percent: Label
var continue_button: Button
var reveals: Array[Control]=[]
var sequence: Tween
var impact_animation: Tween
var finished:=false
var countup:=0.0
var clock:=0.0
func _ready() -> void:
	add_theme_stylebox_override("panel",Style.box(Style.INK,Style.grade_color(data.grade),2,24))
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",10);add_child(stack)
	var head:=HBoxContainer.new();stack.add_child(head)
	var portrait:=TextureRect.new();portrait.texture=preload("res://scripts/ui/presentation/portraits.gd").texture(data.id)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.custom_minimum_size=Vector2(76,76);head.add_child(portrait)
	preload("res://scripts/ui/presentation/portraits.gd").prepare(portrait,data.id)
	var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(titles)
	Style.label(titles,"SHOWDOWN / COMPLETE",13,Style.MINT)
	Style.label(titles,data.name,29).add_theme_font_override("font",Style.BOLD)
	var hero:=HBoxContainer.new();hero.custom_minimum_size.y=245;stack.add_child(hero)
	grade=Style.label(hero,data.grade,160,Style.grade_color(data.grade));grade.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	grade.add_theme_font_override("font",Style.BOLD);grade.custom_minimum_size=Vector2(330,230)
	var score_stack:=VBoxContainer.new();score_stack.alignment=BoxContainer.ALIGNMENT_CENTER;hero.add_child(score_stack)
	Style.label(score_stack,"FINAL SCORE",14,Style.MUTED)
	percent=Style.label(score_stack,"0.00%",48);percent.add_theme_font_override("font",Style.BOLD)
	Style.label(score_stack,"PERSONAL BEST" if data.personal_best else "SHOWDOWN RESULT",14,Style.GOLD if data.personal_best else Style.MUTED)
	var rewards:=HBoxContainer.new();rewards.add_theme_constant_override("separation",14);stack.add_child(rewards)
	for item in [["EXPERIENCE","+%d EXP"%data.exp,Style.LILAC],["NECOINS","+%d"%data.coins,Style.GOLD]]:
		var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Style.box(Style.DEEP,item[2],1,12));rewards.add_child(panel)
		var col:=VBoxContainer.new();panel.add_child(col)
		Style.label(col,item[0],12,item[2]);Style.label(col,item[1],27).add_theme_font_override("font",Style.BOLD)
		reveals.append(panel)
	var extra:=Style.label(stack,("NEW PERSONAL BEST!   " if data.personal_best else "")+("LEVEL UP!  LV %d → %d · HP %d"%[data.level_before,data.level,data.max_hp] if data.level>data.level_before else ""),17,Style.GOLD)
	extra.custom_minimum_size.y=28;reveals.append(extra)
	continue_button=preload("res://scripts/ui/presentation/button.gd").new()
	continue_button.text="SKIP REVEAL  [Z / Enter]";continue_button.custom_minimum_size.y=48
	continue_button.pressed.connect(func():
		if not finished:skip()
		else:advanced.emit())
	stack.add_child(continue_button);continue_button.grab_focus()
	grade.modulate.a=0
	for node in reveals:node.modulate.a=0
	sequence=create_tween()
	sequence.tween_property(self,"countup",float(data.percent),.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sequence.tween_callback(impact)
	sequence.tween_interval(.38)
	for node in reveals:sequence.tween_property(node,"modulate:a",1.0,.18)
	sequence.tween_interval(.35);sequence.tween_callback(finish_reveal)
func _process(delta: float) -> void:
	clock+=delta
	percent.text=Score.display(data.percent if finished else minf(countup,float(data.percent)))
	queue_redraw()
func _draw() -> void:
	var tint: Color=Style.grade_color(data.grade)
	var center:=Vector2(200,215)
	for i in 16:
		var angle:=i*TAU/16+clock*.025
		draw_line(center+Vector2.from_angle(angle)*98,center+Vector2.from_angle(angle)*(120 if i%2 else 140),Color(tint,.14),2)
	draw_arc(center,112,0,TAU,60,Color(tint,.1),1,true)
func impact() -> void:
	grade.modulate.a=1
	impact_animation=Style.pop(grade,2.8,.38)
	Style.burst(self,Vector2(205,220),Style.grade_color(data.grade),44 if data.grade=="S+" else 24)
	if get_node("/root/GameSettings").values.shake and not get_node("/root/VisualSettings").reduced:
		var shake:=create_tween();var home:=position
		for offset in [Vector2(4,0),Vector2(-3,2),Vector2(1,-1),Vector2.ZERO]:shake.tween_property(self,"position",home+offset,.035)
func finish_reveal() -> void:
	finished=true;countup=data.percent;grade.modulate.a=1
	for node in reveals:node.modulate.a=1
	continue_button.text="CONTINUE  [Z / Enter]"
func skip() -> void:
	if is_instance_valid(sequence):sequence.kill()
	if is_instance_valid(impact_animation):impact_animation.kill()
	grade.scale=Vector2.ONE
	finish_reveal()
