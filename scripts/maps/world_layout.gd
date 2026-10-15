extends RefCounted
const Wonderland = preload("res://scripts/wonderland/layout.gd")
static var EXTRA: Dictionary = Wonderland.regions()

## Uniform map coordinates: one map pixel is one 16px terrain tile.
## Staggered NW/NE/SW/SE rectangles retain actual sizes and touch at seams.
const TILE_PIXELS := 16.0
const SIZE := Vector2i(520,372)
const REGIONS := {
	"entrance": {"scene":"forest_entrance", "name":"Forest Entrance", "offset":Vector2i(0,0), "size":Vector2i(200,114)},
	"deep_forest": {"scene":"deep_forest", "name":"Deep Forest", "offset":Vector2i(200,0), "size":Vector2i(320,180)},
	"bart_area": {"scene":"bart_area", "name":"Evil Bart's Area", "offset":Vector2i(0,114), "size":Vector2i(200,114)},
	"flooded_forest": {"scene":"flooded_forest", "name":"Flooded Forest", "offset":Vector2i(200,180), "size":Vector2i(256,192)},
}

static func world_point(area: String, local_point: Vector2) -> Vector2:
	return Vector2(region(area).offset)+local_point/TILE_PIXELS

# Underground terrain has its own atlas; the existing forest atlas stays intact.
const UNDERGROUND := {"underground_cave":{"scene":"underground_cave","name":"Underground Cave","offset":Vector2i.ZERO,"size":preload("res://scripts/world/cave_layout.gd").SIZE*2}}
static func all_regions() -> Dictionary:
	var result := REGIONS.duplicate()
	result.merge(UNDERGROUND)
	result.merge(EXTRA)
	return result
static func region(area: String) -> Dictionary:
	if EXTRA.has(area): return EXTRA[area]
	return UNDERGROUND[area] if UNDERGROUND.has(area) else REGIONS[area]
static func atlas_size(area: String) -> Vector2i:
	if EXTRA.has(area): return Wonderland.extent(area)
	return UNDERGROUND[area].size if UNDERGROUND.has(area) else SIZE
static func visible_regions(area: String) -> Dictionary:
	if EXTRA.has(area):
		var result := {}
		for id in EXTRA:
			if Wonderland.group(id) == Wonderland.group(area): result[id] = EXTRA[id]
		return result
	return UNDERGROUND if UNDERGROUND.has(area) else REGIONS
static func same_map(a: String, b: String) -> bool:
	if EXTRA.has(a) or EXTRA.has(b): return EXTRA.has(a) and EXTRA.has(b) and Wonderland.group(a) == Wonderland.group(b)
	return UNDERGROUND.has(a) == UNDERGROUND.has(b)
