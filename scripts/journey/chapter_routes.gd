extends RefCounted
## Authored main-route control points. Existing local coordinates stay stable.
const MAIN := {
	"entrance": [Vector2(0,912),Vector2(336,912),Vector2(640,1226),Vector2(960,1000),Vector2(1200,660),Vector2(1510,640),Vector2(1840,912),Vector2(2240,1000),Vector2(2635,970),Vector2(2920,912),Vector2(3200,912)],
	"deep_forest": [Vector2(0,912),Vector2(320,912),Vector2(700,760),Vector2(1024,672),Vector2(1344,800),Vector2(1690,1120),Vector2(2080,1060),Vector2(2590,1080),Vector2(2760,1340),Vector2(3104,1820),Vector2(3540,1700),Vector2(3900,1376),Vector2(4400,1056),Vector2(4800,912),Vector2(5120,912)],
	"bart_area": [Vector2(0,912),Vector2(320,912),Vector2(560,1000),Vector2(880,790),Vector2(1240,740),Vector2(1568,1094),Vector2(1870,1060),Vector2(2180,1160),Vector2(2520,1100),Vector2(2860,912),Vector2(3200,912)],
	"flooded_forest": [Vector2(0,912),Vector2(320,912),Vector2(640,720),Vector2(1024,800),Vector2(1376,1130),Vector2(1632,864),Vector2(1760,864),Vector2(1936,864),Vector2(2144,864),Vector2(2440,1100),Vector2(2740,1120),Vector2(3008,1174),Vector2(3290,1090),Vector2(3776,912)]}
## Local compositions: sunny meadow, fern/mushroom banks, pastel glades, reeds.
const GARDENS := {
	"entrance": [Vector2(660,1056),Vector2(980,1100),Vector2(1380,520),Vector2(2510,1070),Vector2(2790,820)],
	"deep_forest": [Vector2(1130,760),Vector2(2520,1070),Vector2(2850,1700),Vector2(3190,1890),Vector2(3650,1600)],
	"bart_area": [Vector2(720,950),Vector2(1280,870),Vector2(1490,1210),Vector2(2020,1240),Vector2(2490,1000)],
	"flooded_forest": [Vector2(1020,1660),Vector2(1680,720),Vector2(2200,900),Vector2(2950,1300),Vector2(3420,2260)]}
const BRIDGE_APPROACHES := [
	[Vector2(3296,2144),Vector2(3248,2180),Vector2(3248,2288),Vector2(3070,2334)],
	[Vector2(3616,2144),Vector2(3660,2144)]]
static func curve(area: String) -> PackedVector2Array:
	return smooth(MAIN[area])
static func smooth(points: Array) -> PackedVector2Array:
	var route:=Curve2D.new()
	route.bake_interval=16
	for i in points.size():
		var tangent:=Vector2.ZERO
		if i>0 and i<points.size()-1:tangent=(points[i+1]-points[i-1]).normalized()*minf(70,points[i].distance_to(points[i-1])*.22)
		route.add_point(points[i],-tangent,tangent)
	return route.get_baked_points()
