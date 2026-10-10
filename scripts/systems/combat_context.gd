extends RefCounted

# Actor ownership must follow the fight, not SceneTree.current_scene (the shell).
static func root_for(actor: Node) -> Node:
	var ancestor := actor
	while ancestor != null:
		if ancestor.is_in_group("combat_root"):
			return ancestor
		ancestor = ancestor.get_parent()
	return actor.get_tree().current_scene
