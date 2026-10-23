extends RefCounted
## Non-spiral formations cover the lower reachable field without folding two
## full rings onto the same lanes. Keep approximately the former active density.
static func visible_count(full_ring_count: int) -> int:
	return maxi(3,ceili(full_ring_count*.60))
static func lower_angle(index: int,count: int,aim: float,phrase: float) -> float:
	var t := (float(index)+.5)/count
	var lean := clampf(aim-PI*.5,-.8,.8)*.30+sin(phrase)*.10
	return lerpf(.16,PI-.16,t)+sin(t*PI)*lean
