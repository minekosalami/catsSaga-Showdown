extends Node2D
# Child artwork offsets only: no writes to player position, velocity or shape.
var accent := Color("#69DAF4")
var sprite: Sprite2D
var rest_offset := Vector2.ZERO
var rest_rotation := 0.0
var focus_alpha := 0.0
var age := 0.0

func _ready() -> void:
	z_index = -1
	sprite = get_parent().get_node("Sprite2D")
	rest_offset = sprite.offset
	rest_rotation = sprite.rotation
	position = get_parent().get_node("CollisionShape2D").position

func _process(delta: float) -> void:
	var player := get_parent()
	if player.health <= 0:
		hide()
		return
	age += delta
	var velocity: Vector2 = player.velocity
	var moving := velocity.length() > 20
	var bounce := sin(age*(8 if moving else 2.2))*(0.6 if moving else 0.4)
	sprite.offset = rest_offset+Vector2(0,bounce/maxf(sprite.scale.y,0.001))
	sprite.rotation = lerp_angle(sprite.rotation,rest_rotation+clampf(velocity.x/450.0,-1,1)*0.035,1-exp(-delta*12))
	focus_alpha = move_toward(focus_alpha,1.0 if Input.is_key_pressed(KEY_SHIFT) else 0.0,delta/0.16)
	queue_redraw()

func _draw() -> void:
	if focus_alpha <= 0:
		return
	# Bracket glyphs complement the EXISTING exact hitbox indicator.
	var radius: float = get_parent().damage_hitbox_radius+9+sin(age*3)*0.6
	for i in range(4):
		var angle := PI/4+i*PI/2
		var p: Vector2 = Vector2.RIGHT.rotated(angle)*radius
		var tangent := Vector2.RIGHT.rotated(angle+PI/2)*3
		draw_line(p-tangent,p+tangent,Color(accent,focus_alpha*0.55),1,true)
