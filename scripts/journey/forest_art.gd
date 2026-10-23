extends RefCounted
## Atlas selection only: every displayed pixel comes from the unchanged LPC sheets.
const ROOT := "res://assets/environment_human/lpc/"
static var regions := {}

static func region(sheet: String,rect: Rect2) -> AtlasTexture:
	var key := sheet+str(rect)
	if regions.has(key):return regions[key]
	var texture := AtlasTexture.new()
	texture.atlas = load(ROOT+sheet+".png")
	texture.region = rect
	texture.filter_clip = true
	regions[key]=texture
	return texture

static func quadrant(cells: Dictionary,cell: Vector2i,q: Vector2i) -> Vector2i:
	var side := Vector2i(-1 if q.x==0 else 1,0)
	var vertical := Vector2i(0,-1 if q.y==0 else 1)
	var h := cells.has(cell+side)
	var v := cells.has(cell+vertical)
	if h and v and not cells.has(cell+side+vertical):
		# Source rows 0–1 contain the artist's four concave corners.
		return Vector2i(3 if q.x==0 else 4,1 if q.y==0 else 2)
	var block := Vector2i(1,3)
	if not h:block.x=0 if q.x==0 else 2
	if not v:block.y=2 if q.y==0 else 4
	return block*2+q

static func paint(surface: TileMapLayer,cells: Dictionary,water := false) -> void:
	surface.clear()
	for cell: Vector2i in cells:
		var interior := true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			if not cells.has(cell+direction):interior=false
		var variant := posmod(cell.x*131+cell.y*47,13)
		for y in 2:
			for x in 2:
				var q := Vector2i(x,y)
				var tile := Vector2i(variant%3,5)*2+q if interior and variant<(5 if water else 2) else quadrant(cells,cell,q)
				surface.set_cell(cell*2+q,0,tile)
