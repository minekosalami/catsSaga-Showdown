extends Control

const ARENA := Vector2i(540, 900)
@export var battle_scene: PackedScene = preload("res://scenes/main.tscn")
@export var arena_size := ARENA
var arena_container: SubViewportContainer
var arena: SubViewport
var battle: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_container = $ArenaContainer
	arena = $ArenaContainer/Arena
	arena.size = arena_size
	arena_container.size = Vector2(arena_size)
	resized.connect(_layout_arena)
	_layout_arena()
	battle = battle_scene.instantiate()
	battle.process_mode = Node.PROCESS_MODE_DISABLED if Session.battle_entry_pending else Node.PROCESS_MODE_PAUSABLE
	arena.add_child(battle)
	if Session.battle_entry_pending:
		# Initialize behind the encounter overlay without advancing music/gameplay.
		battle.music_player.stop()
		battle.set_process_input(false)
		battle.player.set_process_input(false)
		Session._freeze_entry_tree(battle)

func _layout_arena() -> void:
	# Transform the container only; its viewport never stretches or resizes.
	var uniform_scale := minf(size.x / float(arena_size.x), size.y / float(arena_size.y))
	arena_container.scale = Vector2.ONE * uniform_scale
	arena_container.position = (size - Vector2(arena_size) * uniform_scale) * 0.5

func record_victory() -> void:
	if Session.encounter_active:
		Session.evil_bart_defeated = true
		Session.grant_flooded_key()
		if not Session.story_flags.get("bart_victory_dialogue_seen", false):
			Session.story_flags["bart_victory_dialogue_pending"] = true
		Session.save_boss_victory()

func return_to_forest() -> void:
	Session.return_to_forest()

func retry() -> void:
	if battle.game_over and Session.encounter_active:Session.retry_last_save()
	else:Session.transition_to("res://scenes/combat_host.tscn",true)

func main_menu() -> void:
	Session.request_main_menu()

func finish_entry() -> void:
	Session.restore_suspended_modes()
	battle.process_mode = Node.PROCESS_MODE_PAUSABLE
	battle.set_process_input(true)
	battle.player.set_process_input(true)
	battle.music_player.play(0.0)
