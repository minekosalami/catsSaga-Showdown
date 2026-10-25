extends "res://scripts/enemybullet.gd"
var theme = 0
const CLOSE_SPAWN_DISTANCE := 120.0
const CLOSE_SPAWN_WARNING := .3
var arming_time := 0.0
var armed := true
func _ready() -> void:
	super._ready()
	var battle=get_parent()
	if "player" in battle and global_position.distance_to(battle.player.get_node("CollisionShape2D").global_position)<CLOSE_SPAWN_DISTANCE:
		arming_time=CLOSE_SPAWN_WARNING
		armed=false
		collision_layer=0;collision_mask=0;monitoring=false
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not armed and travel_time>=arming_time:
		armed=true
		collision_layer=4;collision_mask=2
		set_deferred("monitoring",true)
func _on_area_entered(area: Area2D) -> void:
	if armed:super._on_area_entered(area)
func _draw() -> void:
	# Code geometry is explicitly permitted. The bright body matches the hitbox;
	# ornamental outlines never disguise a larger damage area.
	var r =body_radius
	var c =bullet_color
	draw_circle(Vector2.ZERO,r+2,Color(c,.12))
	if not armed:
		# Hollow warning travels normally, then fills when the actual core arms.
		draw_arc(Vector2.ZERO,r+2,0,TAU,16,Color(c,.85),1)
		return
	# Every themed silhouette has the same visible circular damage footprint.
	# In particular, a diamond/teardrop no longer hides the circle's outer edges.
	draw_circle(Vector2.ZERO,r+1,Color("#101827"))
	draw_circle(Vector2.ZERO,r,c)
	match theme:
		0: # presents, with ribbon
			draw_rect(Rect2(-r,-r,r*2,r*2),c)
			draw_line(Vector2(-r,0),Vector2(r,0),Color.WHITE,1)
			draw_line(Vector2(0,-r),Vector2(0,r),Color.WHITE,1)
		1: # flame-shaped tear
			draw_colored_polygon(PackedVector2Array([Vector2(0,-r*1.5),Vector2(r,r*.4),Vector2(0,r),Vector2(-r,r*.4)]),c)
			draw_circle(Vector2(0,r*.2),r*.4,Color("#fff3b0"))
		2: # hat brim, circular damage core
			draw_circle(Vector2.ZERO,r,c)
			draw_line(Vector2(-r*1.4,r*.5),Vector2(r*1.4,r*.5),Color.WHITE,1)
		3: # sharp diamond
			draw_polyline(PackedVector2Array([Vector2(0,-r),Vector2(r,0),Vector2(0,r),Vector2(-r,0),Vector2(0,-r)]),c.lightened(.65),1)
		4: # binary-like bars on a readable light core
			draw_circle(Vector2.ZERO,r,c)
			draw_line(Vector2(-2,-3),Vector2(-2,3),Color("#292a3a"),2)
			draw_rect(Rect2(1,-3,3,6),Color("#292a3a"),false,1)
		5: # toast
			draw_rect(Rect2(-r,-r,r*2,r*2),c)
			draw_rect(Rect2(-r*.6,-r*.6,r*1.2,r*1.2),Color("#fff0bb"),false,1)
		6: # speed dash, core remains visible
			draw_line(-direction*r*2,Vector2.ZERO,Color(c,.35),2)
			draw_circle(Vector2.ZERO,r,c)
		7: # spiral
			draw_circle(Vector2.ZERO,r,c)
			draw_arc(Vector2.ZERO,r*.65,animation_time,animation_time+PI*1.6,12,Color.WHITE,1)
