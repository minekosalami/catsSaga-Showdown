extends RefCounted

const Layout = preload("res://scripts/maps/world_layout.gd")
const CELL_TILES := 4
const REVEAL_TILES := 12.0
var regions: Dictionary = {}

func _init() -> void:
	reset()

func grid_size(area: String) -> Vector2i:
	var size: Vector2i = Layout.region(area).size
	return Vector2i(ceili(float(size.x)/CELL_TILES),ceili(float(size.y)/CELL_TILES))

func reset() -> void:
	regions.clear()
	for area in Layout.all_regions():
		var grid := grid_size(area)
		var bits := PackedByteArray()
		bits.resize(ceili(grid.x*grid.y/8.0))
		bits.fill(0)
		regions[area] = bits

func visited(area: String, cell: Vector2i) -> bool:
	var grid := grid_size(area)
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y: return false
	var index := cell.y*grid.x+cell.x
	return (regions[area][index/8] & (1 << (index%8))) != 0

func region_discovered(area: String) -> bool:
	for byte in regions.get(area,PackedByteArray()):
		if byte != 0: return true
	return false

func reveal(area: String, position: Vector2) -> Array[Rect2i]:
	var changed: Array[Rect2i] = []
	if not Layout.all_regions().has(area): return changed
	var point := position/Layout.TILE_PIXELS
	var grid := grid_size(area)
	var center := Vector2i(point/CELL_TILES)
	var radius := ceili(REVEAL_TILES/CELL_TILES)
	var bits: PackedByteArray = regions[area]
	for y in range(maxi(center.y-radius,0),mini(center.y+radius,grid.y-1)+1):
		for x in range(maxi(center.x-radius,0),mini(center.x+radius,grid.x-1)+1):
			var cell := Vector2i(x,y)
			if (Vector2(cell*CELL_TILES)+Vector2.ONE*CELL_TILES*0.5).distance_to(point) > REVEAL_TILES: continue
			var index := y*grid.x+x
			if (bits[index/8] & (1 << (index%8))) != 0: continue
			bits[index/8] |= 1 << (index%8)
			var offset: Vector2i = Layout.region(area).offset
			var size: Vector2i = Layout.region(area).size
			var extent := Vector2i(mini(CELL_TILES,size.x-x*CELL_TILES),mini(CELL_TILES,size.y-y*CELL_TILES))
			changed.append(Rect2i(offset+cell*CELL_TILES,extent))
	regions[area] = bits
	return changed

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for area in Layout.all_regions(): result[area] = Marshalls.raw_to_base64(regions[area])
	return result

func restore(value: Variant) -> bool:
	if not value is Dictionary: return false
	var candidate := {}
	var valid_encoding := RegEx.new()
	valid_encoding.compile("^[A-Za-z0-9+/]*={0,2}$")
	for area in value:
		if not Layout.all_regions().has(area) or not value[area] is String: return false
		var encoded: String = value[area]
		var grid := grid_size(area)
		var bytes := ceili(grid.x*grid.y/8.0)
		if encoded.length() != ceili(bytes/3.0)*4 or valid_encoding.search(encoded) == null: return false
		var decoded := Marshalls.base64_to_raw(encoded)
		if decoded.size() != bytes: return false
		candidate[area] = decoded
	reset()
	for area in candidate: regions[area] = candidate[area]
	return true

func visibility_image(area_id: String = "entrance") -> Image:
	var dimensions := Layout.atlas_size(area_id)
	var result := Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_R8)
	result.fill(Color.BLACK)
	for area in Layout.all_regions():
		if not Layout.same_map(area_id,area): continue
		var grid := grid_size(area)
		var offset: Vector2i = Layout.region(area).offset
		var size: Vector2i = Layout.region(area).size
		for y in grid.y:
			for x in grid.x:
				if not visited(area,Vector2i(x,y)): continue
				for py in range(y*CELL_TILES,mini((y+1)*CELL_TILES,size.y)):
					for px in range(x*CELL_TILES,mini((x+1)*CELL_TILES,size.x)): result.set_pixelv(offset+Vector2i(px,py),Color.WHITE)
	return result
