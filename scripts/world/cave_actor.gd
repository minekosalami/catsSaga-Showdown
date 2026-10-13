extends "res://scripts/world/npc.gd"
const Plan = preload("res://scripts/world/cave_layout.gd")
@export var role := "social"
@export var area := 4
var body: StaticBody2D
var blocker: Sprite2D
var visuals: Array[CanvasItem] = []
const RIDDLE := {"start":"riddle","nodes":{
	"riddle":{"speaker":"Cat","lines":["If you have one cat, and you add another, then you subtract four, then multiply that number by three, then add twenty…","How many letters are in the word 'Cat?'"],"choices":[{"text":"3","next":"correct"},{"text":"14","next":"wrong"},{"text":"6","next":"wrong"}]},
	"wrong":{"speaker":"Cat","lines":["Try again when you're smart enough, peasant!"],"end":"cave_wrong"},
	"correct":{"speaker":"Cat","lines":["How did you know that?? Fine, I've got something for you. I'm feeling generous today, and I just cannot find what this unlocks. Hopefully it'll be better in the hands of a smart person, like you."],"end":"cave_red_key"}}}
func image(texture: Texture2D, height: float, offset := Vector2.ZERO) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*height/texture.get_height()
	sprite.position = offset
	add_child(sprite)
	visuals.append(sprite)
	return sprite
func atlas(path: String, rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = rect
	return texture
func solid(size: Vector2):
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
func _ready():
	super._ready()
	interaction_radius = 110
	match role:
		"red_gate","window":
			var vertical := role == "window"
			var count := 9 if vertical else 6
			for i in count:
				var offset := Vector2(0,(i-(count-1)*.5)*32) if vertical else Vector2((i-(count-1)*.5)*32,0)
				var sprite := image(atlas("res://assets/enironment/sbs_-_top_down_dungeon_pack/Tiles/Walls/Wall-Stone_02-64x64.png",Rect2(384,128,64,64)),32,offset)
				sprite.modulate = Color(0.35,1,.65,.65) if vertical else Color(1,.25,.25)
			solid(Vector2(32,9*32) if vertical else Vector2(6*32,32))
			set_meta("interaction_label","Z  INSPECT WINDOW" if vertical else "Z  UNLOCK RED BARRIER")
		"shortcut_hub","shortcut_junction":
			# A native stone ring surrounds the hole; the only borrowed GFX is the boulder.
			for i in 8:
				var angle := TAU*i/8
				image(atlas("res://assets/enironment/sbs_-_top_down_dungeon_pack/Tiles/Walls/Wall-Stone_02-64x64.png",Rect2(384,128,64,64)),16,Vector2.from_angle(angle)*23)
			blocker = image(atlas("res://assets/enironment/gfx/objects.png",Rect2(320,0,32,32)),64,Vector2(0,-14))
			solid(Vector2(42,28))
			set_meta("interaction_label","Z  SHORTCUT")
		"save":
			image(atlas("res://assets/enironment/gfx/objects.png",Rect2(176,0,32,16)),32,Vector2(0,-12))
			solid(Vector2(24,18))
			var label := Label.new()
			label.text = "SAVE()"
			label.position = Vector2(-30,-54)
			label.add_theme_font_size_override("font_size",12)
			add_child(label)
			set_meta("interaction_label","Z  SAVE")
		_:
			image(load("res://assets/player/player.png.png"),54,Vector2(0,-20))
			solid(Vector2(22,16))
	_process(0)
func cave() -> Node: return get_parent().get_parent()
func can_interact() -> bool:
	if cave().current_room != area and not (role == "red_gate" and cave().current_room == 6): return false
	if role == "red_gate": return not Session.story_flags.get("cave_red_barrier_unlocked",false)
	return true
func _process(_delta):
	if body == null: return
	var unlocked: bool = Session.story_flags.get("cave_red_barrier_unlocked",false)
	var bypass: bool = Session.unrestricted_region_access
	if role == "red_gate":
		for node in visuals: node.visible = not unlocked and not bypass
		body.get_child(0).set_deferred("disabled",unlocked or bypass)
	elif role.begins_with("shortcut"):
		blocker.visible = not unlocked and not bypass
		body.get_child(0).set_deferred("disabled",not blocker.visible)
func handle_interaction(world: Node) -> bool:
	if Session.busy or Session.cave_event_active or world.checking_spawn or world.dialogue.active or Session.world_menu_open(): return false
	match role:
		"riddle":
			if Session.story_flags.get("cave_riddle_completed",false):
				world.dialogue.start_lines([{"speaker":"Cat","text":"You already solved it. Keep the key."}])
			else:
				world.dialogue.finished.connect(func():
					if world.dialogue.outcome == "cave_red_key" and not Session.story_flags.get("cave_riddle_completed",false):
						Session.story_flags["cave_riddle_completed"] = true
						Session.story_flags["cave_red_key_obtained"] = true
						Session.save_current.call_deferred()
				,CONNECT_ONE_SHOT)
				world.dialogue.start_graph(RIDDLE)
		"warning": world.dialogue.start_lines([{"speaker":"Cat","text":"I wouldn't recommend going any deeper..."}])
		"social": world.dialogue.start_lines([{"speaker":"Cat","text":"The counters aren't open yet."}])
		"save":
			var ok := Session.save_current()
			world.dialogue.start_lines([{"speaker":"","text":"Game saved!" if ok else Session.saves.last_error}])
		"window": world.dialogue.start_lines([{"speaker":"","text":"A green seal. The room beyond is unreachable."}])
		"red_gate":
			if Session.story_flags.get("cave_red_key_obtained",false):
				Session.story_flags["cave_red_barrier_unlocked"] = true
				Session.save_current.call_deferred()
			else: world.dialogue.start_lines([{"speaker":"","text":"A red key is required."}])
		"shortcut_hub","shortcut_junction":
			if Session.region_access_allowed(Session.story_flags.get("cave_red_barrier_unlocked",false)):
				cave().use_shortcut(role == "shortcut_hub")
			else: world.dialogue.start_lines([{"speaker":"","text":"The hole is blocked by a heavy boulder."}])
	world.hide_interaction()
	return true
