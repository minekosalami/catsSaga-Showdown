extends RefCounted
## Numbered topology follows the supplied 2026 cave mockup; world cells are 32px.
const CELL := 32
const SIZE := Vector2i(208,184)
const ROOMS := [
	{"id":1,"name":"Entrance","rect":Rect2i(42,7,64,33)},
	{"id":2,"name":"Riddle chamber","rect":Rect2i(4,4,32,38)},
	{"id":3,"name":"Connecting passage","rect":Rect2i(115,3,25,42)},
	{"id":4,"name":"Underground hub","rect":Rect2i(63,45,43,53)},
	{"id":5,"name":"Locked approach","rect":Rect2i(14,47,25,43)},
	{"id":6,"name":"Window chamber","rect":Rect2i(14,98,25,42)},
	{"id":7,"name":"Desaturated chamber","rect":Rect2i(5,146,43,25)},
	{"id":8,"name":"Shortcut junction","rect":Rect2i(72,138,25,42)},
	{"id":9,"name":"Boss 4 approach","rect":Rect2i(103,138,101,42)},
	{"id":10,"name":"Colored hidden room","rect":Rect2i(45,103,53,29)},
]
const ROUTES := [
	{"a":1,"b":2,"points":[Vector2(46,23),Vector2(32,23)]},
	{"a":1,"b":3,"points":[Vector2(102,23),Vector2(120,23)]},
	{"a":3,"b":4,"points":[Vector2(134,36),Vector2(134,79),Vector2(100,79)]},
	{"a":4,"b":5,"points":[Vector2(68,61),Vector2(34,61)]},
	{"a":5,"b":6,"points":[Vector2(26,85),Vector2(26,103)]},
	{"a":6,"b":7,"points":[Vector2(26,135),Vector2(26,151)]},
	{"a":7,"b":8,"points":[Vector2(44,158),Vector2(77,158)]},
	{"a":8,"b":9,"points":[Vector2(92,157),Vector2(109,157)]},
]
const BRANCHES := [
	{"a":3,"b":0,"points":[Vector2(134,57),Vector2(153,57)]},
	{"a":5,"b":0,"points":[Vector2(26,78),Vector2(6,78)]},
]
const RED_GATE := Vector2(26,94)*CELL
const WINDOW := Rect2(41*CELL,115*CELL,CELL,8*CELL)
const SHORTCUT_HUB := Vector2(101,91)*CELL
const SHORTCUT_JUNCTION := Vector2(77,145)*CELL
const ENTRY := Vector2(74,27)*CELL
static func center(index: int) -> Vector2:
	return Vector2(ROOMS[index].rect.get_center())*CELL
static func room(id: int) -> Dictionary: return ROOMS[id-1]
static func network_length() -> float:
	var result := 0.0
	for route in ROUTES:
		for i in range(1,route.points.size()): result += route.points[i-1].distance_to(route.points[i])*CELL
	return result
