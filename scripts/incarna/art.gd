extends RefCounted
## Exact alpha bounds in the creator's sheet. The PNG is never split or altered.
const SHEET_PATH := "res://assets/enironment/bosses/boss4 - incarna/Untitled design/Sprites.png"
const SHEET = preload(SHEET_PATH)
const REGIONS := {
	"mask": Rect2(911,6,468,464), "paw": Rect2(592,16,282,521),
	"cord": Rect2(1491,34,474,493), "spear": Rect2(26,38,508,483),
	"head": Rect2(96,592,422,419), "base": Rect2(1220,597,766,508),
	"eye_left": Rect2(688,738,170,103), "eye_right": Rect2(1006,727,161,98)
}
static func atlas(part: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SHEET
	texture.region = REGIONS[part]
	texture.filter_clip = true
	return texture
