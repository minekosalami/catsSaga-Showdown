extends RefCounted
## Authored geography; deterministic dressing is baked around these routes.
const REVISION := "wonderland_environment_v2"
const MAIN := {
 "wonderland_forest":[[Vector2(32,1000),Vector2(380,1060),Vector2(650,1340),Vector2(1010,1360),Vector2(1280,1728),Vector2(1440,1536),Vector2(1770,1340),Vector2(2050,1050),Vector2(2528,1000)]],
 "mushroom_thicket":[[Vector2(32,1000),Vector2(410,1110),Vector2(740,850),Vector2(1060,780),Vector2(1360,1090),Vector2(1710,960),Vector2(1980,590),Vector2(1570,410),Vector2(1280,192),Vector2(1280,32)]],
 "tea_gardens":[[Vector2(2528,1000),Vector2(2190,1110),Vector2(1810,1000),Vector2(1570,1270),Vector2(1170,1320),Vector2(870,1100),Vector2(970,800),Vector2(1350,650),Vector2(1530,410),Vector2(1280,192),Vector2(1280,32)]],
 "royal_woods":[[Vector2(1280,1888),Vector2(1330,1590),Vector2(1710,1410),Vector2(2090,1460),Vector2(2450,1160),Vector2(2870,1050),Vector2(3180,1170),Vector2(3808,1000)],[Vector2(2870,1050),Vector2(3030,790),Vector2(3320,650),Vector2(3210,420),Vector2(3200,32)]],
 "wonderland_village":[[Vector2(32,1000),Vector2(310,1050),Vector2(950,950),Vector2(1360,1170),Vector2(1920,1200),Vector2(2390,1110),Vector2(2710,1400),Vector2(2560,1728),Vector2(2560,1888)],[Vector2(950,950),Vector2(1010,670),Vector2(640,380),Vector2(640,32)]],
 "queens_castle":[[Vector2(640,1888),Vector2(740,1650),Vector2(1010,1530),Vector2(1000,1230),Vector2(1280,1030),Vector2(1280,900)],[Vector2(1920,1888),Vector2(1830,1620),Vector2(1510,1480),Vector2(1560,1210),Vector2(1280,1030)]]}
const LOOPS := {
 "wonderland_forest":[[Vector2(380,1060),Vector2(420,650),Vector2(820,470),Vector2(1240,550),Vector2(1710,430),Vector2(2130,650),Vector2(2050,1050)],[Vector2(1770,1340),Vector2(2190,1420),Vector2(2260,1670),Vector2(1880,1730),Vector2(1440,1536)]],
 "mushroom_thicket":[[Vector2(410,1110),Vector2(480,1540),Vector2(940,1640),Vector2(1260,1450),Vector2(1360,1090)],[Vector2(1260,1450),Vector2(1680,1650),Vector2(2130,1410),Vector2(2220,990),Vector2(1980,590)],[Vector2(740,850),Vector2(660,480),Vector2(960,310),Vector2(1280,192)]],
 "tea_gardens":[[Vector2(870,1100),Vector2(480,1170),Vector2(440,1530),Vector2(880,1650),Vector2(1170,1320)],[Vector2(1570,1270),Vector2(1790,1600),Vector2(2130,1500),Vector2(2190,1110)],[Vector2(970,800),Vector2(620,560),Vector2(890,370),Vector2(1280,192)]],
 "royal_woods":[[Vector2(1330,1590),Vector2(700,1510),Vector2(400,1120),Vector2(690,680),Vector2(1270,600),Vector2(1710,900),Vector2(1710,1410)],[Vector2(1710,900),Vector2(2080,450),Vector2(2520,510),Vector2(3030,790)],[Vector2(3180,1170),Vector2(3400,1550),Vector2(2930,1670),Vector2(2450,1160)]],
 "wonderland_village":[[Vector2(310,1050),Vector2(480,1650),Vector2(1130,1720),Vector2(1700,1700),Vector2(2230,1690),Vector2(2560,1728)],[Vector2(2390,1110),Vector2(2760,880),Vector2(3460,1050),Vector2(3540,1630),Vector2(3000,1710),Vector2(2710,1400)],[Vector2(1010,670),Vector2(1760,690),Vector2(2040,420),Vector2(2750,370),Vector2(3460,1050)]],
 "queens_castle":[[Vector2(740,1650),Vector2(420,1440),Vector2(400,1050),Vector2(700,930),Vector2(1000,1230)],[Vector2(1830,1620),Vector2(2160,1370),Vector2(2140,1010),Vector2(1830,930),Vector2(1560,1210)]]}
const CLEARINGS := {
 "wonderland_forest":[Rect2(650,850,610,400),Rect2(1780,1250,520,400)],
 "mushroom_thicket":[Rect2(430,1130,600,420),Rect2(1490,1130,600,420)],
 "tea_gardens":[Rect2(1070,800,560,410)],
 "royal_woods":[Rect2(680,780,640,420),Rect2(2640,1250,600,420)],
 "wonderland_village":[Rect2(1560,850,670,430)],
 "queens_castle":[Rect2(950,1100,640,430)]}
const PALETTES := {
 "wonderland_forest":Color("#b8ffb6"),"mushroom_thicket":Color("#b0f5ef"),"tea_gardens":Color("#e1ffba"),
 "royal_woods":Color("#b6efcf"),"wonderland_village":Color("#e8fac3"),"queens_castle":Color("#def7ce")}
static func smooth(points: Array) -> PackedVector2Array:
 var curve:=Curve2D.new();curve.bake_interval=24
 for i in points.size():
  var tangent:=Vector2.ZERO
  if i>0 and i<points.size()-1:tangent=(points[i+1]-points[i-1]).normalized()*75
  curve.add_point(points[i],-tangent,tangent)
 return curve.get_baked_points()
