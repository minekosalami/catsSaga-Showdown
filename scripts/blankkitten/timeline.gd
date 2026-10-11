extends Resource
## One authoritative cue sheet, editable phase offset and deterministic patterns.
const END := 145.71
const BPM := 140.0
const BEAT := 60.0 / BPM
const MEASURE := BEAT * 4
const HALF_MEASURE := BEAT * 2
const MORPH := 0.75
const STARTS := [0.0, 13.71, 34.28, 61.71, 68.57, 89.14, 102.85, 130.28]
const NAMES := ["Introduction", "Falling pillars", "Bouncing fireball", "Break", "Intersecting laser grid", "Jumping beams", "Showdown()", "Ending"]
const BOXES := [Rect2(70,440,400,320), Rect2(40,480,460,270), Rect2(100,430,340,340), Rect2(70,440,400,320), Rect2(70,430,400,340), Rect2(40,500,460,230), Rect2(30,480,480,270), Rect2(70,440,400,320)]
const GRAVITY := [false, true, false, false, false, true, true, false]
@export var musical_phase_offset := 0.0
@export var pattern_seed := 73129
## Empty means no ending dialogue. Author lines here; completion never waits on Z.
@export var ending_lines: Array[String] = []

static func stage_at(clock: float) -> int:
	var stage := 0
	for index in range(1, STARTS.size()):
		if clock >= STARTS[index]:
			stage = index
	return stage

static func morph_at(clock: float) -> int:
	for index in range(1, STARTS.size()):
		if clock >= STARTS[index] - MORPH and clock < STARTS[index]:
			return index
	return -1

static func distortion_at(clock: float) -> int:
	return 3 if clock >= 102.85 else (2 if clock >= 68.57 else (1 if clock >= 34.28 else 0))

static func fire_at(clock: float) -> float:
	if clock < 89.14:
		return 0
	if clock < 102.85:
		return smoothstep(89.14,102.85,clock)
	if clock < 130.28:
		return 1
	return 1 - smoothstep(130.28,END,clock)
