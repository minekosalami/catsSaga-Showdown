extends Node
const PRESETS:={"clear":Vector3(0,.08,.3),"overcast":Vector3(0,.75,.5),"light_rain":Vector3(.35,.65,.55),"heavy_rain":Vector3(.85,.95,1)}
var state ="clear"
var rain =0.0
var cloud =.08
var wind =.3
var wait =70.0
var rng =RandomNumberGenerator.new()
var light_audio: AudioStreamPlayer
var heavy_audio: AudioStreamPlayer
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	light_audio=audio(preload("res://assets/weather_human/weather_rain.ogg"))
	heavy_audio=audio(preload("res://assets/weather_human/weather_rain_heavy.ogg"))
func audio(stream: AudioStream) -> AudioStreamPlayer:
	var player =AudioStreamPlayer.new()
	player.stream=stream.duplicate();player.stream.loop=true
	player.bus="Ambience";player.volume_db=-80
	add_child(player)
	return player
func set_weather(value: String) -> void:
	if PRESETS.has(value):state=value;wait=rng.randf_range(75,140)
func _process(delta: float) -> void:
	var world=get_tree().current_scene
	var enabled:bool=world!=null and world.name=="Overworld" and not get_parent().busy
	if enabled:
		wait-=delta
		if wait<=0:
			var choices =PRESETS.keys();choices.erase(state)
			set_weather(choices[rng.randi_range(0,choices.size()-1)])
		var target:Vector3=PRESETS[state]
		var blend =1-exp(-delta/6)
		rain=lerpf(rain,target.x,blend);cloud=lerpf(cloud,target.y,blend);wind=lerpf(wind,target.z,blend)
	var region_scale =1.0 if get_parent().area_id=="flooded_forest" else (.8 if get_parent().area_id=="deep_forest" else .65)
	var audible:bool=enabled and get_node("/root/Ambience").enabled
	for pair in [[light_audio,clampf(rain*2,0,1)*(1-clampf((rain-.4)*2,0,1))],[heavy_audio,clampf((rain-.3)*2,0,1)]]:
		var level:float=float(pair[1])*region_scale if audible else 0.0
		var voice:AudioStreamPlayer=pair[0]
		if level>.005 and not voice.playing:voice.play()
		voice.volume_db=lerpf(voice.volume_db,-27+linear_to_db(maxf(.001,level)),1-exp(-delta*2))
		if level<.005 and voice.volume_db<-70:voice.stop()
