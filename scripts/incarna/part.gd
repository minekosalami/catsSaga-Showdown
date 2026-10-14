extends Polygon2D
## A small textured lattice gives fur/jaws/limbs flex, rather than rigid wobble.
const Art = preload("res://scripts/incarna/art.gd")
var rest := PackedVector2Array()
var part_size := Vector2.ZERO
var softness := 1.0
var rows := 8
var columns := 5

func build(kind: String, width: float, flex: float = 1.0) -> void:
	var region: Rect2 = Art.REGIONS[kind]
	part_size = Vector2(width, width*region.size.y/region.size.x)
	softness = flex
	texture = Art.SHEET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vertices := PackedVector2Array()
	var coordinates := PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	for y in range(rows+1):
		for x in range(columns+1):
			var fraction := Vector2(float(x)/columns,float(y)/rows)
			vertices.append((fraction-Vector2.ONE*.5)*part_size)
			coordinates.append(region.position+fraction*region.size)
	for y in rows:
		for x in columns:
			var index := y*(columns+1)+x
			faces.append(PackedInt32Array([index,index+1,index+columns+2]))
			faces.append(PackedInt32Array([index,index+columns+2,index+columns+1]))
	rest = vertices
	polygon = vertices
	uv = coordinates
	polygons = faces
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://shaders/incarna_monochrome.gdshader")
	material = ink

func flex(time: float, phase: float, tension: float = 0.0, blink: float = 1.0) -> void:
	var vertices := rest.duplicate()
	for i in vertices.size():
		var p: Vector2 = rest[i]
		var down := p.y/part_size.y+.5
		var weight := smoothstep(.20,1.0,down)
		p.x += sin(time*1.18+phase+down*1.5)*weight*part_size.x*.028*softness
		p.y += sin(time*.84+phase)*weight*part_size.y*.018*softness
		p.x += tension*weight*weight*part_size.x*.065
		p.y *= blink
		vertices[i] = p
	polygon = vertices
