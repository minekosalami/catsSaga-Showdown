extends RefCounted
## Active geography only; archived maps and save exploration remain recoverable.
const REVISION := "journey_layout_v1"
const ORDER := ["entrance","deep_forest","bart_area","flooded_forest"]
const SCENES := {"entrance":"forest_entrance","deep_forest":"deep_forest","bart_area":"bart_area","flooded_forest":"flooded_forest"}
const SIZES := {"entrance":Vector2(3200,1824),"deep_forest":Vector2(5120,2880),"bart_area":Vector2(3200,1824),"flooded_forest":Vector2(4096,3072)}
const SPAWNS := {"entrance":Vector2(240,912),"deep_forest":Vector2(224,912),"bart_area":Vector2(224,912),"flooded_forest":Vector2(224,912)}
const SEAM_Y := 912.0
static func active(area: String) -> bool: return area in ORDER
static func scene(area: String) -> String: return "res://scenes/journey/"+SCENES[area]+".tscn"
static func points(area: String) -> PackedVector2Array:
	var width: float = SIZES[area].x
	var result := PackedVector2Array([Vector2(0,SEAM_Y),Vector2(320,SEAM_Y)])
	var phase := float(ORDER.find(area))*0.8
	for x in range(640,int(width)-480,352):
		result.append(Vector2(x,SEAM_Y+sin(x*.005+phase)*240+sin(x*.011)*70))
	result.append(Vector2(width-320,SEAM_Y))
	if area!="flooded_forest": result.append(Vector2(width,SEAM_Y)) # Final road ends naturally in its eastern grove.
	return result
