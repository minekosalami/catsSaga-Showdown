extends Node2D
# Child artwork offsets only: no writes to player position, velocity or shape.
var accent := Color("#69DAF4")
var sprite: Sprite2D
var rest_offset := Vector2.ZERO
var rest_rotation := 0.0
var focus_alpha := 0.0
var age := 0.0
var rest_scale := Vector2.ONE
var last_shoot_timer := 0.0
var recoil := 0.0

func _ready() -> void:
	z_index = -1
	sprite = get_parent().get_node("Sprite2D")
	rest_offset = sprite.offset
	rest_rotation = sprite.rotation
	rest_scale = sprite.scale
	# Doppelcat's existing sprint shader already owns its flash treatment.
	if sprite.material==null:preload("res://scripts/ui/pixel_art.gd").apply(sprite)
	else:sprite.material.set_shader_parameter("display_size",sprite.texture.get_size()*rest_scale.abs())
	position = get_parent().get_node("CollisionShape2D").position

func _process(delta: float) -> void:
	var player := get_parent()
	if player.health <= 0:
		hide()
		return
	age += delta
	var velocity: Vector2 = player.velocity
	var moving := velocity.length() > 20
	if velocity.x!=0:sprite.flip_h = velocity.x>0
	if player.shoot_timer>last_shoot_timer+.05:recoil = 1.0
	last_shoot_timer = player.shoot_timer
	recoil = maxf(0,recoil-delta*13)
	var hit := clampf(player.hit_flash_timer/player.HIT_FLASH_DURATION,0,1)
	var breath := sin(age*2.2)*.009
	sprite.scale = rest_scale*Vector2(1+breath+recoil*.035+hit*.045,1-breath-recoil*.025-hit*.035)
	var bounce := sin(age*(8 if moving else 2.2))*(0.6 if moving else 0.4)
	sprite.offset = rest_offset+Vector2(0,(bounce+recoil*2.5)/maxf(sprite.scale.y,0.001))
	sprite.rotation = lerp_angle(sprite.rotation,rest_rotation+clampf(velocity.x/450.0,-1,1)*0.035,1-exp(-delta*12))
	focus_alpha = move_toward(focus_alpha,1.0 if Input.is_action_pressed("focus") else 0.0,delta/0.16)
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
