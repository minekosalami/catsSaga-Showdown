extends Node2D
## Presentation-only observer. The existing soundtrack remains the combat clock.
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var battle: Node
var view: SubViewport
var composite: SubViewportContainer
var material_fx: ShaderMaterial
var analyzer: AudioEffectSpectrumAnalyzerInstance
var identity := 0
var clock := 0.0
var section := 0.0
var bass := 0.0
var detail := 0.0
var reactive_enabled := false
var reduced_fx := false
var motion := .8
func _ready() -> void:
	battle = get_parent()
	identity = 2 if battle.scene_file_path.contains("blankkitten") else (1 if battle.scene_file_path.contains("boss2") else 0)
	z_index = -2
	composite = SubViewportContainer.new()
	composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(composite)
	view = SubViewport.new()
	view.size = Vector2i(270,450)
	view.disable_3d = true
	view.gui_disable_input = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	composite.add_child(view)
	var layer := ColorRect.new()
	layer.name = "SurrealStage"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material_fx = ShaderMaterial.new()
	material_fx.shader = preload("res://shaders/surreal_battle.gdshader")
	material_fx.set_shader_parameter("identity",identity)
	material_fx.set_shader_parameter("floor_sheet",preload("res://assets/wonderland_human/ninja/tileset_floor.png"))
	layer.material = material_fx
	view.add_child(layer)
	update_clock(0)
func enable_analysis() -> void:
	var index := AudioServer.get_bus_index("BossMusic")
	if index<0:
		index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index,"BossMusic")
		AudioServer.set_bus_send(index,"Master")
		var spectrum := AudioEffectSpectrumAnalyzer.new()
		spectrum.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(index,spectrum)
	var audio := battle.get_node("MusicPlayer" if identity==0 else "Music") as AudioStreamPlayer
	audio.bus = "BossMusic" # Unity gain, read-only analysis; does not restart playback.
	analyzer = AudioServer.get_bus_effect_instance(index,0)
	reactive_enabled = true
func _process(delta: float) -> void:
	var active := identity>0 or ("boss" in battle and is_instance_valid(battle.boss))
	if active and not reactive_enabled:enable_analysis()
	if reactive_enabled and analyzer != null:
		var low := analyzer.get_magnitude_for_frequency_range(40,180).length()
		var high := analyzer.get_magnitude_for_frequency_range(1800,6500).length()
		bass = lerpf(bass,clampf((linear_to_db(maxf(low,.000001))+60)/42,0,1),1-exp(-delta*8))
		detail = lerpf(detail,clampf((linear_to_db(maxf(high,.000001))+65)/42,0,1),1-exp(-delta*6))
	update_clock(battle.elapsed_time)
func update_clock(time: float) -> void:
	clock = time
	var settings := get_node("/root/VisualSettings")
	reduced_fx = settings.reduced or (identity==2 and battle.reduced_effects)
	motion = settings.motion
	var target := Vector2i(135,225) if reduced_fx else Vector2i(270,450)
	if view.size!=target or composite.scale.x!=540.0/target.x:
		view.size = target
		composite.size = Vector2(target)
		composite.scale = Vector2.ONE*(540.0/target.x)
		view.get_child(0).size = Vector2(target)
	var active := identity>0 or ("boss" in battle and is_instance_valid(battle.boss))
	if identity==2:
		if is_instance_valid(battle.hazards): battle.hazards.ball_material.set_shader_parameter("human_flame",preload("res://scripts/ui/human_effects.gd").frame("flame",int(clock*14)))
		section = [0.05,.26,.43,.10,.65,.78,1.0,.08][Cue.stage_at(clock)]
	else:
		section = battle.get_node("CinematicArena").look.stage_at(clock)
	material_fx.set_shader_parameter("clock",clock)
	material_fx.set_shader_parameter("section",section)
	material_fx.set_shader_parameter("motion",settings.motion)
	material_fx.set_shader_parameter("reduced",1.0 if reduced_fx else 0.0)
	material_fx.set_shader_parameter("boss_active",active)
	material_fx.set_shader_parameter("bass",bass if active else 0.0)
	material_fx.set_shader_parameter("detail",detail if active else 0.0)
	var beat: float = Cue.BEAT if identity==2 else battle.get_node("CinematicArena").look.measure_seconds
	var pulse := exp(-fposmod(clock,beat)*7.0)
	material_fx.set_shader_parameter("energy",pulse if active else 0.0)
	var arena: Rect2 = battle.arena_rect if identity==2 else Rect2(16,300,508,570)
	material_fx.set_shader_parameter("arena",Vector4(arena.position.x/540,arena.position.y/900,arena.size.x/540,arena.size.y/900))
	queue_redraw()

func _draw() -> void:
	if not reactive_enabled or reduced_fx or section<.16: return
	# Human sparkle frames remain above the player's dodging floor, behind actors.
	var count := 8+int(section*10)
	for i in range(count):
		var phase := clock*.11*motion+i*TAU/count
		var radius := 92.0+22*sin(i*2.1+clock*.17*motion)
		var point := Vector2(270,210)+Vector2(cos(phase)*radius,sin(phase)*radius*.74)
		var size := 6.0+section*7+sin(clock*2+i)*2
		draw_texture_rect(preload("res://scripts/ui/human_effects.gd").frame("sparkle",int(clock*8+i)),Rect2(point-Vector2.ONE*size*.5,Vector2.ONE*size),false,Color(1,.8,.92,.25+section*.2))
