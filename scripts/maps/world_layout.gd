extends RefCounted

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
	return Vector2(REGIONS[area].offset)+local_point/TILE_PIXELS
