extends Node2D
## Read-only actor feedback. No new shapes, state, health or clock mutations.
var player: Node2D
var last_hp:=-1
var healing:=0.0
var phase:=0.0
func _ready() -> void:
	z_index=8
func _process(delta: float) -> void:
	phase+=delta;healing=maxf(0,healing-delta)
	if last_hp>=0 and player.health>last_hp:healing=.42
	last_hp=player.health
	visible=player.health>0 and (player.shield_remaining>0 or healing>0)
	if visible:queue_redraw()
func _draw() -> void:
	var point:=player.position
	var shape:=player.get_node_or_null("CollisionShape2D") as Node2D
	if shape!=null:point=get_parent().to_local(shape.global_position)
	if player.shield_remaining>0:
		draw_arc(point,25,phase*.6,phase*.6+TAU*.77,40,Color("#74e7cf88"),1.5,true)
		for i in 3:draw_circle(point+Vector2.from_angle(phase*.6+i*TAU/3)*28,1.4,Color("#d4fff299"))
	if healing>0:
		draw_arc(point,20+(1-healing/.42)*14,0,TAU,36,Color(.45,.9,.8,healing*.6),1,true)
