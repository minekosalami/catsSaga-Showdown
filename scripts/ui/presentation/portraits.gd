extends RefCounted
static func texture(id: String) -> Texture2D:
	if id.begins_with("ordinary_"):
		return load("res://assets/encounters/enemy_%d.png"%int(id.trim_prefix("ordinary_")))
	return {"bart":preload("res://assets/bartboss.png"),"boss2":preload("res://assets/enironment/bosses/boss2/bosstwo.png"),"blankkitten":preload("res://assets/enironment/bosses/boss3-BlankKitten/normalKitten-transparent.png")}.get(id,null)

static func prepare(picture: TextureRect, id: String) -> void:
	if id!="ordinary_4":return
	var backing:=ColorRect.new();backing.color=Color("#6d7b94")
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;backing.show_behind_parent=true
	picture.add_child(backing);backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
