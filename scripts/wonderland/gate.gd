extends "res://scripts/world/npc.gd"
const Plan = preload("res://scripts/wonderland/layout.gd")
@export_enum("pink","castle") var kind := "pink"
var barrier: CollisionShape2D
var ornament: Node2D
var last_open := false
func flag() -> String: return Plan.DOOR_OPEN if kind == "pink" else Plan.CASTLE_OPEN
func open_now() -> bool: return Session.region_access_allowed(Session.story_flags.get(flag(),false))
func _ready() -> void:
	super._ready()
	interaction_radius = 130
	set_meta("interaction_label","Z  PINK WONDERLAND DOOR" if kind == "pink" else "Z  CASTLE GATES")
	ornament = preload("res://scripts/wonderland/ornament.gd").new()
	ornament.kind = "pink_door" if kind == "pink" else "castle_gate"
	ornament.accent = Color("#e68fbe")
	ornament.scale = Vector2.ONE*2
	add_child(ornament)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	barrier = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(112,36)
	barrier.shape = shape
	body.add_child(barrier)
	_process(0)
func _process(_delta: float) -> void:
	var opened := open_now()
	barrier.set_deferred("disabled",opened)
	if opened != last_open:
		last_open = opened
		ornament.kind = "arch" if opened else ("pink_door" if kind == "pink" else "castle_gate")
		ornament.queue_redraw()
func handle_interaction(_world: Node) -> bool:
	if kind == "pink" and not Session.story_flags.get(Plan.DOOR_OPEN,false) and Session.story_flags.get(Plan.PINK_KEY,false):
		Session.story_flags[Plan.DOOR_OPEN] = true
		Session.save_current()
		Session.show_notification("Pink Wonderland Door unlocked.","WonderlandNotification")
	else:
		Session.show_notification("The way is open." if open_now() else ("A Pink Wonderland Key is required." if kind == "pink" else "The castle gates are locked."),"WonderlandNotification")
	return true
