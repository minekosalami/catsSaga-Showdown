extends Node
const Catalog=preload("res://scripts/encounters/catalog.gd")
## Session visit state is intentionally separate from durable story progress.
var region =""
var population: Dictionary={}
var navigation_cache: Dictionary={}
var active: Dictionary={}
var checkpoint ={"area":"entrance","position":[240.0,912.0]}
var clock =0.0
var protection_until =3.0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
func _process(delta: float) -> void:
	var session=get_parent()
	var scene=get_tree().current_scene
	if not session.busy and scene!=null and scene.name=="Overworld" and not session.world_menu_open() and not scene.dialogue.active:clock+=delta
func reset(point: Dictionary={"area":"entrance","position":[240.0,912.0]}) -> void:
	region="";population.clear();active.clear();navigation_cache.clear()
	checkpoint=point.duplicate(true)
	protection_until=clock+Catalog.RETURN_PROTECTION_SECONDS
func visit(area: String) -> void:
	if region!=area:
		region=area;population.clear()
func activate_checkpoint(area: String, point: Vector2) -> void:
	checkpoint={"area":area,"position":[point.x,point.y]}
func begin(world: Node, actor: Node) -> void:
	var session=get_parent()
	if not active.is_empty() or session.busy or session.encounter_active or get_tree().paused or clock<protection_until or world.dialogue.active or world.checking_spawn or world.automatic_encounter_pending or session.world_menu_open():return
	if world.encounters.safe(world.player.position) or actor.ignore_until>clock:return
	active={"id":actor.encounter_id,"kind":actor.kind,"area":session.area_id,"position":world.player.position,"settled":false}
	session.return_position=world.player.position
	session.encounter_id="ordinary"
	session.encounter_active=true
	world.encounters.store_positions()
	if not await session.transition_to("res://scenes/encounters/combat_host.tscn",true):active.clear()
func resolve(result: String) -> void:
	var session=get_parent()
	if active.is_empty() or active.settled or result not in ["victory","defeat","flee"] or session.busy:return
	active.settled=true
	var actor: Dictionary=population.get(active.id,{})
	if result=="victory" and not actor.is_empty() and actor.alive:
		actor.alive=false
		session.story_progress.necoins+=Catalog.REWARD
		session.story_progress.changed.emit()
	elif result=="flee" and not actor.is_empty():
		actor.retreat=true
		actor.ignore_until=clock+Catalog.FLEE_IGNORE_SECONDS
	var point:Vector2=active.position
	var area:String=active.area
	if result=="defeat":
		area=checkpoint.area
		point=Vector2(checkpoint.position[0],checkpoint.position[1])
	protection_until=clock+Catalog.RETURN_PROTECTION_SECONDS
	session.encounter_active=false
	session.area_id=area
	session.return_position=point
	session.restore_position=true
	# Never reload the manual save or replace inventory, quest, currency or fog.
	await session.transition_to("res://scenes/world/overworld.tscn")
	active.clear()
