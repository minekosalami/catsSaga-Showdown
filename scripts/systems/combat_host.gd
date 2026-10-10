extends Control

const ARENA := Vector2i(540, 900)
@export var battle_scene: PackedScene = preload("res://scenes/main.tscn")
var arena_container: SubViewportContainer
var arena: SubViewport
var battle: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_container = $ArenaContainer
	arena = $ArenaContainer/Arena
	arena.size = ARENA
	resized.connect(_layout_arena)
	_layout_arena()
	battle = battle_scene.instantiate()
	battle.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.add_child(battle)

func _layout_arena() -> void:
	# Transform the container only; its viewport never stretches or resizes.
	var uniform_scale := minf(size.x / float(ARENA.x), size.y / float(ARENA.y))
	arena_container.scale = Vector2.ONE * uniform_scale
	arena_container.position = (size - Vector2(ARENA) * uniform_scale) * 0.5

func record_victory() -> void:
	if Session.encounter_active:
		Session.evil_bart_defeated = true

func return_to_forest() -> void:
	Session.return_to_forest()

func retry() -> void:
	Session.transition_to("res://scenes/combat_host.tscn")

func main_menu() -> void:
	Session.main_menu()
