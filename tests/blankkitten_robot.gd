extends RefCounted
## Movement-only test pilot. No health edits, cheats, or timeline overrides.
static func steer(game: Node, time: float) -> Vector2:
	var star: Node = game.player
	if game.stage in [1,6]:
		for pillar in game.hazards.pillars:
			if time >= pillar.warning and time < pillar.impact+game.hazards.floor_hold:
				var offset: float = pillar.gap.get_center().x-star.position.x
				return Vector2(signf(offset) if absf(offset) > 2.1 else 0,0)
		return Vector2.ZERO
	if game.stage == 2:
		# Choose a direction with the best minimum clearance over 0.45 seconds.
		var best := -INF
		var move := Vector2.ZERO
		for i in range(-1,16):
			var direction := Vector2.ZERO if i == -1 else Vector2.RIGHT.rotated(i*TAU/16)
			var score := INF
			for j in range(1,10):
				var dt := j*0.05
				var candidate: Vector2 = star.position+direction*star.speed*dt
				candidate = candidate.clamp(game.arena_rect.position+Vector2.ONE*star.RADIUS,game.arena_rect.end-Vector2.ONE*star.RADIUS)
				var ball: Dictionary = game.hazards.shapes_at(time+dt)[0]
				score = minf(score,candidate.distance_to(ball.circle))
			score -= (star.position+direction*star.speed*0.45).distance_to(game.arena_rect.get_center())*0.04
			if score > best:
				best = score
				move = direction
		return move
	if game.stage == 4:
		var beams: Array = game.hazards.shapes_at(time)
		if beams.size() == 2:
			var first: Rect2 = beams[0].rect
			var second: Rect2 = beams[1].rect
			var vertical := first.size.x < first.size.y
			var gate := (first.end.y+second.position.y)*0.5 if vertical else (first.end.x+second.position.x)*0.5
			var offset: float = gate-(star.position.y if vertical else star.position.x)
			return (Vector2(0,signf(offset)) if vertical else Vector2(signf(offset),0)) if absf(offset) > 2.1 else Vector2.ZERO
	if game.stage == 5 and star.grounded:
		for beam in game.hazards.shapes_at(time):
			if not beam.warning and beam.rect.get_center().x > star.position.x and beam.rect.get_center().x-star.position.x < 100:
				star.jump_requested = true
	return Vector2.ZERO
