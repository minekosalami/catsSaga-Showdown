extends Resource
# Presentation data only. These cues never schedule or alter attacks.
@export var boss_name := "Boss"
@export var accent := Color("#69DAF4")
@export var secondary := Color("#8067C5")
@export var flooded := false
@export var angular := false
@export var measure_seconds := 1.6
@export var cues := PackedFloat32Array()
@export var stages := PackedFloat32Array()
@export var final_phase_time := 0.0

func stage_at(clock: float) -> float:
	var level := 0.0
	for i in range(cues.size()):
		if clock >= cues[i]:
			# Two seconds of sine-eased visual evolution after an existing cue.
			var previous := stages[i-1] if i > 0 else 0.0
			var blend := (1-cos(PI*clampf((clock-cues[i])/2.0,0,1)))*0.5
			level = lerpf(previous,stages[i],blend)
	return level
