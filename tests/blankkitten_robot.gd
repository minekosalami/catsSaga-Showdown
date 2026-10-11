extends RefCounted
## Deterministic movement-only pilot; no HP edits, invincibility or clock changes.
static func steer(game: Node, time: float) -> Vector2:
	var star: Node = game.player
	if game.stage in [1,6]:
		for pillar in game.hazards.pillars:
			if time >= pillar.warning and time < pillar.impact+game.hazards.floor_hold+.04:
				var offset: float = pillar.gap.get_center().x-star.position.x
				return Vector2(signf(offset) if absf(offset) > 2.1 else 0,0)
		return Vector2.ZERO
	if game.stage == 2:
		var bounds: Rect2 = game.arena_rect.grow(-game.hazards.WALL_DEPTH-star.RADIUS-3)
		var best := -INF
		var move := Vector2.ZERO
		for i in range(-1,24):
			var direction := Vector2.ZERO if i == -1 else Vector2.RIGHT.rotated(i*TAU/24)
			var score := INF
			for j in range(1,12):
				var dt := j*.05
				var candidate: Vector2 = (star.position+direction*star.speed*dt).clamp(bounds.position,bounds.end)
				var ball: Vector2 = game.hazards.ball_position(time+dt)
				score = minf(score,candidate.distance_to(ball)-game.hazards.BALL_RADIUS-star.RADIUS)
			if score > best:
				best = score
				move = direction
		var next: Vector2 = star.position+move*star.speed/60
		if next.x < bounds.position.x or next.x > bounds.end.x: move.x = 0
		if next.y < bounds.position.y or next.y > bounds.end.y: move.y = 0
		return move
	if game.stage == 4:
		var offset: Vector2 = game.hazards.grid_pocket(time+.12).get_center()-star.position
		return offset.normalized() if offset.length() > 2.1 else Vector2.ZERO
	if game.stage == 5:
		for pair in game.hazards.jump_pairs():
			var x: float = (game.arena_rect.end.x+20 if pair.direction < 0 else game.arena_rect.position.x-20)+(time-pair.start)*pair.speed*pair.direction
			var eta: float = (star.position.x-x)/(pair.speed*pair.direction)
			var desired: float = pair.height+pair.gap/2-star.RADIUS
			var cut: float = (star.jump_speed-sqrt(star.jump_speed*star.jump_speed-2*star.gravity*(desired-star.release_speed*star.release_speed/(2*star.gravity))))/star.gravity
			var apex: float = cut+star.release_speed/star.gravity
			if star.grounded and eta > 0 and eta <= apex+.016 and star.get_meta("pilot_pair",-1) != pair.id:
				star.set_meta("pilot_pair",pair.id)
				star.set_meta("pilot_jump_time",time)
				star.set_meta("pilot_cut",cut)
				star.jump_requested = true
		if not star.grounded and time >= float(star.get_meta("pilot_jump_time",time))+float(star.get_meta("pilot_cut",1)):
			star.jump_released = true
	return Vector2.ZERO
