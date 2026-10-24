extends RefCounted
## Active-time integral of squared no-damage streaks, independent of audio seeks.
const GRADES := [[100.0,"S+"],[90.0,"A+"],[80.0,"A"],[70.0,"B"],[60.0,"C"],[40.0,"D"],[0.0,"F"]]
var elapsed := 0.0
var streak := 0.0
var completed_squares := 0.0
var hits := 0
var finished := false
func advance(delta: float) -> void:
	if finished: return
	elapsed+=maxf(0,delta)
	streak+=maxf(0,delta)
func damage() -> void:
	if finished: return
	completed_squares+=streak*streak
	streak=0
	hits+=1
func percent() -> float:
	if hits==0: return 100.0
	if elapsed<=0: return 0.0
	return clampf(100.0*(completed_squares+streak*streak)/(elapsed*elapsed),0,99.999999)
static func grade(value: float) -> String:
	for entry in GRADES:
		if value>=entry[0]: return entry[1]
	return "F"
static func display(value: float) -> String:
	# Never round a nonperfect score up to a displayed 100%.
	return "100%" if value==100.0 else "%.2f%%" % (floor(value*100.0)/100.0)
