extends RefCounted
## Sixteen hand-authored spaces use a 4×4 organization; special area IDs stay stable.
const CELL := 32
const SIZE := Vector2i(188,128)
const ROOMS := [
	{"id":1,"name":"Entrance refuge","slot":Vector2i(1,0),"rect":Rect2i(40,6,30,20),"shape":"shelter"},
	{"id":2,"name":"Riddle alcove","slot":Vector2i(0,0),"rect":Rect2i(5,5,25,23),"shape":"lobe"},
	{"id":3,"name":"Dripping passage","slot":Vector2i(2,0),"rect":Rect2i(80,6,25,23),"shape":"split"},
	{"id":4,"name":"Hearth hub","slot":Vector2i(1,1),"rect":Rect2i(40,36,34,28),"shape":"shelter"},
	{"id":5,"name":"Red seal approach","slot":Vector2i(0,1),"rect":Rect2i(5,38,25,24),"shape":"split"},
	{"id":6,"name":"Window grotto","slot":Vector2i(0,2),"rect":Rect2i(5,70,25,23),"shape":"lobe"},
	{"id":7,"name":"Quiet hollow","slot":Vector2i(0,3),"rect":Rect2i(6,101,25,22),"shape":"split"},
	{"id":8,"name":"Lower junction","slot":Vector2i(1,3),"rect":Rect2i(42,102,28,23),"shape":"shelter"},
	{"id":9,"name":"Incarna approach","slot":Vector2i(3,3),"rect":Rect2i(117,100,67,25),"shape":"long"},
	{"id":10,"name":"Sealed colored chamber","slot":Vector2i(1,2),"rect":Rect2i(38,72,32,22),"shape":"lobe"},
	{"id":11,"name":"Supply cache","slot":Vector2i(3,0),"rect":Rect2i(115,5,26,22),"shape":"split"},
	{"id":12,"name":"Lantern market","slot":Vector2i(2,1),"rect":Rect2i(83,37,26,23),"shape":"shelter"},
	{"id":13,"name":"Sleeping quarters","slot":Vector2i(3,1),"rect":Rect2i(118,36,27,26),"shape":"lobe"},
	{"id":14,"name":"Old reading nook","slot":Vector2i(2,2),"rect":Rect2i(81,71,29,24),"shape":"split"},
	{"id":15,"name":"Echo pool","slot":Vector2i(3,2),"rect":Rect2i(118,72,27,22),"shape":"lobe"},
	{"id":16,"name":"Last watch","slot":Vector2i(2,3),"rect":Rect2i(81,103,25,22),"shape":"shelter"},
]
const SHAPES := {
	"shelter":[Vector2(.13,.10),Vector2(.43,.03),Vector2(.67,.08),Vector2(.88,.05),Vector2(.98,.27),Vector2(.94,.65),Vector2(.83,.94),Vector2(.55,.96),Vector2(.33,.85),Vector2(.10,.92),Vector2(.03,.62),Vector2(.07,.32)],
	"lobe":[Vector2(.17,.04),Vector2(.48,.08),Vector2(.76,.02),Vector2(.93,.21),Vector2(.88,.42),Vector2(.98,.63),Vector2(.81,.91),Vector2(.58,.98),Vector2(.38,.89),Vector2(.12,.95),Vector2(.03,.73),Vector2(.12,.48),Vector2(.02,.28)],
	"split":[Vector2(.09,.14),Vector2(.32,.03),Vector2(.55,.12),Vector2(.78,.04),Vector2(.97,.24),Vector2(.85,.43),Vector2(.96,.65),Vector2(.76,.95),Vector2(.54,.89),Vector2(.34,.97),Vector2(.09,.80),Vector2(.02,.57),Vector2(.18,.39)],
	"long":[Vector2(.02,.28),Vector2(.08,.10),Vector2(.29,.06),Vector2(.45,.12),Vector2(.66,.05),Vector2(.89,.12),Vector2(.97,.30),Vector2(.98,.65),Vector2(.91,.91),Vector2(.74,.95),Vector2(.52,.87),Vector2(.32,.96),Vector2(.08,.88),Vector2(.02,.68)]
}
const ROUTES := [
	{"a":1,"b":2,"points":[Vector2(44,16),Vector2(36,16),Vector2(34,13),Vector2(28,13)]},
	{"a":1,"b":3,"points":[Vector2(66,15),Vector2(73,15),Vector2(75,20),Vector2(84,20)]},
	{"a":3,"b":4,"points":[Vector2(91,26),Vector2(91,31),Vector2(71,31),Vector2(68,40)]},
	{"a":3,"b":11,"points":[Vector2(101,18),Vector2(110,18),Vector2(113,13),Vector2(121,13)]},
	{"a":4,"b":5,"points":[Vector2(44,49),Vector2(35,49),Vector2(31,47),Vector2(26,47)]},
	{"a":4,"b":12,"points":[Vector2(69,48),Vector2(78,48),Vector2(79,45),Vector2(87,45)]},
	{"a":12,"b":13,"points":[Vector2(104,47),Vector2(111,47),Vector2(114,51),Vector2(121,51)]},
	{"a":5,"b":6,"points":[Vector2(17,59),Vector2(17,65),Vector2(18,69),Vector2(18,74)]},
	{"a":6,"b":7,"points":[Vector2(19,90),Vector2(19,95),Vector2(25,97),Vector2(25,105)]},
	{"a":7,"b":8,"points":[Vector2(27,113),Vector2(34,113),Vector2(37,117),Vector2(47,117)]},
	{"a":8,"b":16,"points":[Vector2(65,115),Vector2(73,115),Vector2(77,112),Vector2(85,112)]},
	{"a":16,"b":9,"points":[Vector2(103,113),Vector2(111,113),Vector2(116,112),Vector2(123,112)]},
	{"a":8,"b":14,"points":[Vector2(58,106),Vector2(58,98),Vector2(79,98),Vector2(86,90)]},
	{"a":14,"b":15,"points":[Vector2(105,82),Vector2(112,82),Vector2(115,85),Vector2(122,85)]},
]
const BRANCHES := [
	{"a":11,"b":0,"points":[Vector2(130,13),Vector2(145,13),Vector2(149,19),Vector2(145,23)]},
	{"a":5,"b":0,"points":[Vector2(14,54),Vector2(3,54)]},
	{"a":14,"b":0,"points":[Vector2(98,91),Vector2(103,99),Vector2(111,99)]},
	{"a":13,"b":0,"points":[Vector2(128,56),Vector2(145,57),Vector2(149,64)]},
]
const POOLS := [
	[Vector2(127,76),Vector2(138,75),Vector2(142,80),Vector2(139,89),Vector2(130,90),Vector2(125,86),Vector2(125,81)],
	[Vector2(8,81),Vector2(12,77),Vector2(15,78),Vector2(16,83),Vector2(13,88),Vector2(9,88),Vector2(7,85)],
	[Vector2(97,8),Vector2(100,9),Vector2(102,13),Vector2(100,15),Vector2(97,14),Vector2(95,11)],
	[Vector2(84,75),Vector2(88,73),Vector2(91,76),Vector2(90,79),Vector2(86,79)],
]
const RED_GATE := Vector2(17,66)*CELL
const WINDOW := Rect2(34*CELL,79*CELL,CELL,6*CELL)
const SHORTCUT_HUB := Vector2(67,58)*CELL
const SHORTCUT_JUNCTION := Vector2(49,108)*CELL
const ENTRY := Vector2(53,17)*CELL
const WARNING := Vector2(58,47)*CELL
const SOCIAL := Vector2(67,46)*CELL
const SAVE_POINT := Vector2(62,56)*CELL
const REST := Vector2(46,53)*CELL
static func center(index: int) -> Vector2: return Vector2(ROOMS[index].rect.get_center())*CELL
static func room(id: int) -> Dictionary: return ROOMS[id-1]
static func polygon(id: int) -> PackedVector2Array:
	var area := room(id)
	var result := PackedVector2Array()
	for point in SHAPES[area.shape]: result.append(Vector2(area.rect.position)+point*Vector2(area.rect.size))
	return result
static func network_length() -> float:
	var result := 0.0
	for route in ROUTES+BRANCHES:
		for i in range(1,route.points.size()): result += route.points[i-1].distance_to(route.points[i])*CELL
	return result
