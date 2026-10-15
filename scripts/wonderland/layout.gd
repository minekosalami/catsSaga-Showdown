extends RefCounted
## Outdoor offsets are physical adjacency, in the existing map's 16px units.
const OUTDOORS := {
	"wonderland_forest":{"name":"Wonderland Forest","offset":Vector2i(160,240),"size":Vector2i(160,120)},
	"tea_gardens":{"name":"Tea Gardens","offset":Vector2i(0,240),"size":Vector2i(160,120)},
	"mushroom_thicket":{"name":"Mushroom Thicket","offset":Vector2i(320,240),"size":Vector2i(160,120)},
	"royal_woods":{"name":"Royal Woods","offset":Vector2i(0,120),"size":Vector2i(240,120)},
	"wonderland_village":{"name":"Wonderland Village","offset":Vector2i(240,120),"size":Vector2i(240,120)},
	"queens_castle":{"name":"Queen's Castle Grounds","offset":Vector2i(160,0),"size":Vector2i(160,120)}
}
const BUILDINGS := [
	{"id":"mushroom_cottage","name":"Mushroom Cottage","kind":"mushroom_house","point":Vector2(640,640),"color":Color("#ed647c")},
	{"id":"teapot_house","name":"Teapot House","kind":"teapot_house","point":Vector2(1472,480),"color":Color("#62d5dc")},
	{"id":"flower_shop","name":"Flower Shop","kind":"house2","point":Vector2(2432,608),"color":Color("#b47eeb")},
	{"id":"clockmakers_house","name":"Clockmaker's House","kind":"clock_house","point":Vector2(3264,704),"color":Color("#f3bc6a")},
	{"id":"bakery","name":"Bakery","kind":"house1","point":Vector2(576,1344),"color":Color("#ef8b7c")},
	{"id":"royal_gift_shop","name":"Royal Gift Shop","kind":"house4","point":Vector2(1504,1536),"color":Color("#ad88eb")},
	{"id":"storytellers_cottage","name":"Storyteller's Cottage","kind":"house3","point":Vector2(2576,1472),"color":Color("#66cbb8")},
	{"id":"tiny_pink_house","name":"Tiny Pink House","kind":"pink_house","point":Vector2(3328,1376),"color":Color("#ed87bc")}
]
const CASTLE_ROOMS := {
	"castle_hall":{"name":"Grand Entrance Hall","offset":Vector2i(80,60),"size":Vector2i(80,60)},
	"royal_library":{"name":"Royal Library","offset":Vector2i(0,60),"size":Vector2i(80,60)},
	"banquet_hall":{"name":"Banquet Hall","offset":Vector2i(160,60),"size":Vector2i(80,60)},
	"throne_room":{"name":"Throne Room","offset":Vector2i(80,0),"size":Vector2i(80,60)}
}
## Links use opposite edge normals and equal world-space seam coordinates.
const LINKS := [
	["wonderland_forest","west",1000,"tea_gardens","east",1000],
	["wonderland_forest","east",1000,"mushroom_thicket","west",1000],
	["tea_gardens","north",1280,"royal_woods","south",1280],
	["mushroom_thicket","north",1280,"wonderland_village","south",2560],
	["royal_woods","north",3200,"queens_castle","south",640],
	["wonderland_village","north",640,"queens_castle","south",1920],
	["royal_woods","east",1000,"wonderland_village","west",1000],
	["castle_hall","west",480,"royal_library","east",480],
	["castle_hall","east",480,"banquet_hall","west",480],
	["castle_hall","north",640,"throne_room","south",640]
]
const FLOODED_DOOR := Vector2(3072,208)
const CHEST := Vector2(5536,3584)
const PINK_KEY := "pink_wonderland_key_obtained"
const CHEST_OPEN := "incarna_wonderland_chest_opened"
const DOOR_OPEN := "wonderland_door_unlocked"
const CASTLE_OPEN := "wonderland_castle_unlocked"

static func regions() -> Dictionary:
	var all := OUTDOORS.duplicate(true)
	all.merge(CASTLE_ROOMS.duplicate(true))
	for building in BUILDINGS: all[building.id] = {"name":building.name,"offset":Vector2i.ZERO,"size":Vector2i(80,60)}
	for id in all: all[id]["scene"] = "../wonderland/"+id
	return all

static func group(id: String) -> String:
	if OUTDOORS.has(id): return "wonderland"
	if CASTLE_ROOMS.has(id): return "castle_interior"
	return id

static func extent(id: String) -> Vector2i:
	if OUTDOORS.has(id): return Vector2i(480,360)
	if CASTLE_ROOMS.has(id): return Vector2i(240,120)
	return Vector2i(80,60)

static func edge(id: String, side: String, along: float, inset := 32.0) -> Vector2:
	var size := Vector2(regions()[id].size)*16
	match side:
		"north": return Vector2(along,inset)
		"south": return Vector2(along,size.y-inset)
		"west": return Vector2(inset,along)
	return Vector2(size.x-inset,along)

static func inward(side: String) -> Vector2:
	return {"north":Vector2.DOWN,"south":Vector2.UP,"west":Vector2.RIGHT,"east":Vector2.LEFT}[side]

static func unlock_castle() -> bool:
	# Future quest interface: one persistent flag, no invented items or quest logic.
	var tree := Engine.get_main_loop() as SceneTree
	var session := tree.root.get_node("Session")
	session.story_flags[CASTLE_OPEN] = true
	return session.save_current()
