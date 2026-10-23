extends RefCounted
## Quarter-tile autotiling selects original artist pixels; no image is generated.
## Each logical 32px cell renders as four 16px quadrants, including concave banks.
static func quadrant(cells: Dictionary, cell: Vector2i, q: Vector2i, water: bool) -> Vector2i:
	var side := Vector2i(-1 if q.x==0 else 1,0)
	var vertical := Vector2i(0,-1 if q.y==0 else 1)
	var h := cells.has(cell+side)
	var v := cells.has(cell+vertical)
	var center_y := 7 if water else 8
	if h and v and not cells.has(cell+side+vertical):
		# Four inside corners of the source sheet's grass island.
		return Vector2i(34 if q.x==0 else 33,(16 if water else 18) if q.y==0 else (15 if water else 17))
	var tile := Vector2i(12,center_y)
	if not h: tile.x = 11 if q.x==0 else 13
	if not v: tile.y = center_y+(-1 if q.y==0 else 1)
	return tile*2+q

static func paint(surface: TileMapLayer,cells: Dictionary,water: bool) -> void:
	for cell: Vector2i in cells:
		for y in 2:
			for x in 2:
				var q := Vector2i(x,y)
				surface.set_cell(cell*2+q,0,quadrant(cells,cell,q,water))
