extends "res://scenes/player.gd"
# Encounter-specific abilities; Evil Bart continues to use the original player.
@export var sprint_multiplier := 1.8
@export var sprint_capacity_seconds := 5.0
@export var recharge_seconds := 3.0
@export var activation_protection_seconds := 0.2
@export var activation_cooldown_seconds := 0.6
@export var protected_activation_threshold := 0.2
@export var damage_protection_seconds := 1.5
var stamina := 1.0
var sprinting := false
var sprint_protection := 0.0
var sprint_cooldown := 0.0
var exhausted_until_release := false
var previous_hit_center := Vector2.ZERO
var afterimage_clock := 0.0
var laser_spark_cooldown := 0.0
var protected_crossings := 0

func _ready() -> void:
	super._ready()
	previous_hit_center = hit_center()
	$Sprite2D.material = ShaderMaterial.new()
	$Sprite2D.material.shader = preload("res://shaders/boss2_player.gdshader")

func hit_center() -> Vector2:
	return global_position + $CollisionShape2D.position

func try_protected_activation(focused: bool) -> bool:
	if focused or stamina < protected_activation_threshold or sprint_cooldown > 0 or health <= 0:
		return false
	sprint_protection = activation_protection_seconds
	sprint_cooldown = activation_cooldown_seconds
	return true

func _input(event: InputEvent) -> void:
	super._input(event)
	if event.is_action_pressed("ability") and not event.is_echo() and not get_tree().paused:
		try_protected_activation(Input.is_action_pressed("focus"))

func update_sprint(delta: float, held: bool, focused: bool) -> void:
	sprint_protection = maxf(0,sprint_protection-delta)
	sprint_cooldown = maxf(0,sprint_cooldown-delta)
	laser_spark_cooldown = maxf(0,laser_spark_cooldown-delta)
	if not held:
		exhausted_until_release = false
	sprinting = held and not focused and not exhausted_until_release and stamina > 0 and health > 0
	if sprinting:
		stamina = maxf(0,stamina-delta/sprint_capacity_seconds)
		if stamina <= 0.000001:
			stamina = 0
			exhausted_until_release = true
	else:
		stamina = minf(1,stamina+delta/recharge_seconds)

func _physics_process(delta: float) -> void:
	previous_hit_center = hit_center()
	var focused := Input.is_action_pressed("focus")
	update_sprint(delta,Input.is_action_pressed("ability"),focused)
	var normal_speed := speed
	if sprinting:
		speed *= sprint_multiplier
	else:
		# Releasing X or focusing immediately caps existing sprint momentum.
		velocity = velocity.limit_length(focus_speed if focused else normal_speed)
	super._physics_process(delta)
	speed = normal_speed
	afterimage_clock -= delta
	var effects: Node = get_parent().get_node_or_null("Effects")
	if sprinting and velocity.length() > 30 and afterimage_clock <= 0 and effects != null:
		afterimage_clock = 0.065
		effects.afterimage($Sprite2D)
	$Sprite2D.material.set_shader_parameter("protected_flash",sprint_protection > 0 and not get_node("/root/GameSettings").values.flashing)
	$Sprite2D.material.set_shader_parameter("hit_flash",0.0 if get_node("/root/GameSettings").values.flashing else hit_flash_timer/HIT_FLASH_DURATION)

func take_damage(amount: int) -> void:
	if sprint_protection > 0:
		return
	var before := health
	super.take_damage(amount)
	if health < before:
		invulnerability_timer = damage_protection_seconds
		$Sprite2D.material.set_shader_parameter("hit_flash",0.0 if get_node("/root/GameSettings").values.flashing else 1.0)
		get_parent().notify_hit(hit_center())

func notify_laser_contact(point: Vector2) -> void:
	if sprint_protection > 0 and laser_spark_cooldown <= 0:
		laser_spark_cooldown = 0.12
		protected_crossings += 1
		get_parent().effects.burst(point,Color.WHITE,8,120)

func shoot() -> void:
	pass
func activate_saturate() -> void:
	pass
