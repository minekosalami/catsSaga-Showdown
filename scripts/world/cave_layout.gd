extends RefCounted
## Authored chamber graph, in 32px cave cells. Bake once, edit the resulting scene.
const CELL := 32
const SIZE := Vector2i(640,512)
const ROOMS := [
	{"name":"Entrance chamber","center":Vector2i(60,55),"radius":Vector2i(25,20)},
	{"name":"Dripping gallery","center":Vector2i(180,70),"radius":Vector2i(31,22)},
	{"name":"Slate hall","center":Vector2i(335,48),"radius":Vector2i(34,17)},
	{"name":"Split vault","center":Vector2i(515,90),"radius":Vector2i(27,24)},
	{"name":"Echo pools","center":Vector2i(570,225),"radius":Vector2i(30,27)},
	{"name":"Basalt gallery","center":Vector2i(420,210),"radius":Vector2i(30,20)},
	{"name":"Crossroads cavern","center":Vector2i(265,180),"radius":Vector2i(37,29)},
	{"name":"Low grotto","center":Vector2i(90,220),"radius":Vector2i(24,28)},
	{"name":"Stillwater hollow","center":Vector2i(55,390),"radius":Vector2i(30,23)},
	{"name":"Stone bridge","center":Vector2i(215,370),"radius":Vector2i(36,24)},
	{"name":"Lower gallery","center":Vector2i(330,460),"radius":Vector2i(32,20)},
	{"name":"Broken pillars","center":Vector2i(455,390),"radius":Vector2i(30,26)},
	{"name":"Deep antechamber","center":Vector2i(570,455),"radius":Vector2i(26,24)},
	{"name":"Deep cavern","center":Vector2i(565,340),"radius":Vector2i(42,32)},
]
# Winding routes deliberately bow between chambers instead of straight spokes.
const ROUTES := [
	[0,1,Vector2i(104,42),Vector2i(138,90)],
	[1,2,Vector2i(221,105),Vector2i(278,30)],
	[2,3,Vector2i(385,32),Vector2i(447,126)],
	[3,4,Vector2i(595,130),Vector2i(537,174)],
	[4,5,Vector2i(525,270),Vector2i(473,184)],
	[5,6,Vector2i(355,257),Vector2i(306,141)],
	[6,7,Vector2i(218,235),Vector2i(154,165)],
	[7,0,Vector2i(38,157),Vector2i(106,105)],
	[7,8,Vector2i(112,270),Vector2i(25,328)],
	[8,9,Vector2i(116,435),Vector2i(173,342)],
	[9,10,Vector2i(239,438),Vector2i(288,402)],
	[10,11,Vector2i(380,475),Vector2i(399,365)],
	[11,12,Vector2i(483,454),Vector2i(540,401)],
	[12,13,Vector2i(610,415),Vector2i(530,389)],
	[13,4,Vector2i(612,304),Vector2i(520,280)],
	[9,6,Vector2i(178,300),Vector2i(298,270)],
	[11,5,Vector2i(370,327),Vector2i(453,271)],
]
static func center(index: int) -> Vector2:
	return Vector2(ROOMS[index].center)*CELL+Vector2.ONE*CELL*.5
static func route_points(route: Array) -> PackedVector2Array:
	return PackedVector2Array([center(route[0]),Vector2(route[2])*CELL,Vector2(route[3])*CELL,center(route[1])])
static func network_length() -> float:
	var total := 0.0
	for route in ROUTES:
		var points := route_points(route)
		for i in range(1,points.size()): total += points[i].distance_to(points[i-1])
	return total
