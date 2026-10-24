extends RefCounted
const NAMES := ["Purrrresents!", "FireKittens", "TopCat", "Sharpurr", "BiNarty", "Toasters", "2kMEOWpH", "Sir Swirlur"]
const COLORS := [Color("#ee7279"), Color("#ffac59"), Color("#a9c9ec"), Color("#eb8fa8"), Color("#d2d4ed"), Color("#f3d38f"), Color("#8ce0ee"), Color("#c5a0ff")]
const ENEMY_HP := 72 # 10.8 seconds at 100% shot accuracy, before travel/dodging.
const HIT_INVULNERABILITY := 1.5
const REWARD := 10
const FLEE_OUTCOMES := 2 # One success out of two equiprobable integers: exactly 50%.
const MAX_POPULATION := 4
const SAFE_RADIUS := 170.0
const DETECTION_RADIUS := 460.0
const PURSUIT_LEASH := 720.0
const WANDER_SPEED := 80.0
const CHASE_SPEED := 155.0
const FLEE_IGNORE_SECONDS := 10.0
const RETURN_PROTECTION_SECONDS := 3.0
const BULLET_CAP := 128
static func texture(kind: int) -> Texture2D:
	return load("res://assets/encounters/enemy_%d.png"%clampi(kind,0,7))
