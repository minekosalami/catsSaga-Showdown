extends RefCounted
## All authored timings use soundtrack seconds. No playback-rate changes.
const END := 113.14
const BPM := 140.0
const BEAT := 60.0 / BPM
const MEASURE := BEAT * 4.0
const EMERGENCE := 10.0
const SIZE := Vector2i(1280, 720)
const PLAY_AREA := Rect2(96, 424, 1088, 236)
const SPAWN := Vector2(640, 618)
const RIG_CENTER := Vector2(640, -280)
const CUES := [0.0, 20.57, 27.42, 41.14, 82.28, 96.0, 102.85, END]
const RETURN_PREP := 82.28 - BEAT * 2.0
const SPEAR_SPACING := 0.1
const SPEAR_WARNING := 1.15
const LUNGE_WARNING := 1.05
const LUNGE_TRAVEL := 0.22
const LUNGE_HOLD := 0.15
const LUNGE_RETURN := 0.72
const PAW_RADIUS := 26.0
const BURST_WARNING := 1.2
const MAX_SHOTS := 160
const SPEAR_RESERVE := 30
const MAX_ZONES := 4
const PATTERN_SEED := 406140

static func section_at(time: float) -> int:
	var section := 0
	for i in range(1, CUES.size()):
		if time >= CUES[i]: section = i
	return section

static func tuning(section: int) -> Dictionary:
	# One continuous encounter; these are intensity changes, not separate phases.
	return [
		{"cadence": MEASURE*4, "spears":10, "speed":420.0, "fragments":12, "zones":1},
		{"cadence": MEASURE*3, "spears":10, "speed":440.0, "fragments":14, "zones":1},
		{"cadence": MEASURE*2, "spears":12, "speed":480.0, "fragments":18, "zones":1},
		{"cadence": MEASURE*2, "spears":14, "speed":510.0, "fragments":26, "zones":2},
		{"cadence": MEASURE*1.5, "spears":15, "speed":540.0, "fragments":30, "zones":2},
		{"cadence": MEASURE*3, "spears":12, "speed":440.0, "fragments":16, "zones":1},
		{"cadence": MEASURE*4, "spears":10, "speed":390.0, "fragments":12, "zones":1}
	][clampi(section,0,6)]
