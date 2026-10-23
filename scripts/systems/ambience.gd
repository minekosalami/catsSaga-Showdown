extends Node
## Human field recordings only. Independent of music playback and battle clocks.
signal enabled_changed(value: bool)
const DIRECTORY := "res://assets/ambience_human/"
# Gain corrections measured from the unchanged Ogg files (ffmpeg volumedetect).
# Keeps the naturally quiet water/insect recordings audible beside the wind.
const RECORDING_GAIN := {"ComboWind":0.0,"birdsongnl":7.5,"robin2":8.8,"bluejay":2.6,"Crickets_At_NightCombo":19.7,"Spooky_Water_Drops":18.1,"drippingwater_drip_a":0.0,"drippingwater_drip_b":0.0,"lake_waves_2_calm":18.0,"small_waterfall":8.7}
const SETTINGS := "user://audio-options.cfg"
var enabled := true
var profile := ""
var weights := {}
var voices: Array[Dictionary] = []
var schedules := {}
var rng := RandomNumberGenerator.new()
var quietness := 0.0
var water_proximity := 0.0
var water_blend := 0.0
var elapsed := 0.0
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 rng.randomize()
 load_settings()
 for bus_name in ["Ambience","CaveAmbience"]:
  if AudioServer.get_bus_index(bus_name) >= 0: continue
  AudioServer.add_bus()
  var index := AudioServer.bus_count-1
  AudioServer.set_bus_name(index,bus_name)
  AudioServer.set_bus_send(index,"Master" if bus_name == "Ambience" else "Ambience")
  if bus_name == "CaveAmbience":
   var room := AudioEffectReverb.new()
   room.room_size = .8
   room.wet = .22
   room.dry = .85
   room.damping = .65
   AudioServer.add_bus_effect(index,room)
 get_tree().scene_changed.connect(sync_scene)
 sync_scene.call_deferred()
func load_settings() -> void:
 var config := ConfigFile.new()
 if config.load(SETTINGS) == OK: enabled = bool(config.get_value("audio","ambient_audio",true))
func set_enabled(value: bool) -> void:
 enabled = value
 var config := ConfigFile.new()
 config.load(SETTINGS)
 config.set_value("audio","ambient_audio",enabled)
 var error := config.save(SETTINGS)
 if error != OK: push_warning("Could not save ambient audio setting: %s"%error)
 enabled_changed.emit(enabled)
func profile_for(area: String) -> String:
 if area == "underground_cave": return "cave"
 if area == "flooded_forest": return "wetland"
 var plan := preload("res://scripts/wonderland/layout.gd")
 if plan.OUTDOORS.has(area): return "wonderland"
 if plan.regions().has(area): return "interior"
 return "forest"
func sync_scene() -> void:
 var scene := get_tree().current_scene
 profile = profile_for(Session.area_id) if scene != null and scene.scene_file_path == "res://scenes/world/overworld.tscn" else ""
 quietness = 0
 water_proximity = 0
 water_blend = 0
 if not profile.is_empty() and not schedules.has(profile): schedules[profile] = {"bed":0.0,"bird":elapsed+2,"detail":elapsed+4,"water":elapsed+3}
func play_recording(file: String,base_db: float,region: String,pitch := 1.0) -> AudioStreamPlayer:
 var player := AudioStreamPlayer.new()
 player.stream = load(DIRECTORY+file+".ogg")
 player.bus = "CaveAmbience" if region == "cave" else "Ambience"
 player.pitch_scale = pitch
 player.volume_db = -80
 add_child(player)
 player.play()
 voices.append({"player":player,"base":base_db+float(RECORDING_GAIN.get(file,0.0)),"profile":region,"age":0.0,"length":player.stream.get_length()/pitch})
 return player
func _process(delta: float) -> void:
 elapsed += delta
 water_blend = move_toward(water_blend,water_proximity,delta/.7)
 var active := profile if enabled and not Session.busy else ""
 for key in schedules:
  weights[key] = move_toward(float(weights.get(key,0.0)),1.0 if key == active else 0.0,delta/1.4)
  if key != active: continue
  var times: Dictionary = schedules[key]
  if elapsed >= times.bed:
   var name := "Spooky_Water_Drops" if key == "cave" else "ComboWind"
   var voice := play_recording(name,-28 if key == "cave" else (-34 if key == "interior" else -24),key,.85 if key == "cave" else 1.0)
   voice.set_meta("ambient_bed",true)
   times.bed = elapsed+maxf(3,voice.stream.get_length()/voice.pitch_scale-2.5)
  if elapsed >= times.bird and key != "cave":
   var birds := ["birdsongnl","robin2","bluejay"]
   play_recording(birds[rng.randi_range(0,2)],-40 if key == "interior" else -25,key,rng.randf_range(.97,1.03))
   times.bird = elapsed+rng.randf_range(9,19)
  if elapsed >= times.detail:
   if key == "cave":play_recording("drippingwater_drip_a" if rng.randf()<.5 else "drippingwater_drip_b",-23,key,rng.randf_range(.9,1.05))
   elif key != "interior":play_recording("Crickets_At_NightCombo",-34 if key == "wonderland" else -32,key)
   times.detail = elapsed+rng.randf_range(8,14) if key == "cave" else elapsed+rng.randf_range(66,82)
  if elapsed >= times.water and (key == "wetland" or water_proximity>.1):
   var water := play_recording("small_waterfall" if water_proximity>.1 and key == "wonderland" else "lake_waves_2_calm",-29 if key == "wetland" else -28,key)
   water.set_meta("ambient_water",true)
   times.water = elapsed+maxf(10,water.stream.get_length()-2)
 for i in range(voices.size()-1,-1,-1):
  var voice: Dictionary = voices[i]
  voice.age += delta
  if not voice.player.playing:
   voice.player.queue_free()
   voices.remove_at(i)
   continue
  var attack := minf(.8,voice.length*.08)
  var release := minf(1.5,voice.length*.18)
  if voice.player.has_meta("ambient_bed"):attack = minf(2.5,voice.length*.45);release = attack
  var envelope := minf(1,minf(voice.age/maxf(.001,attack),(voice.length-voice.age)/maxf(.001,release)))
  var gain: float = float(weights.get(voice.profile,0.0))*maxf(0,envelope)
  if voice.player.has_meta("ambient_water") and voice.profile != "wetland":gain *= water_blend
  var quiet_db := -24*quietness if voice.profile == "cave" else 0.0
  voice.player.volume_db = maxf(-80,voice.base+linear_to_db(maxf(gain,.0001))+quiet_db)

func _exit_tree() -> void:
 for voice in voices:
  if is_instance_valid(voice.player):
   voice.player.stop()
   voice.player.stream = null
 voices.clear()
 schedules.clear()
