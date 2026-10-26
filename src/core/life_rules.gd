class_name LifeRules
extends RefCounted
## The hearts rules in one place (owner, round 5: "increasing it is so easy, make it
## rare"; "when all life ends, the level should restart"):
##   - Hearts last the whole level. A hit costs one; a pit fall costs one and sends the
##     hero back to the last lamp.
##   - Respawning at a lamp never refills hearts.
##   - The only heal is a rare heart pickup: at most one per level, off the main path.
##   - At zero hearts the level starts over from the beginning with full hearts.

const MAX_HEART_PICKUPS := 1


static func after_fall(hearts: int) -> int:
	return maxi(0, hearts - 1)


static func after_hit(hearts: int) -> int:
	return maxi(0, hearts - 1)


## Hearts after a respawn at a lamp: unchanged.
static func after_respawn(hearts: int, _max_hearts: int) -> int:
	return hearts


static func after_heal(hearts: int, max_hearts: int, amount: int = 1) -> int:
	return mini(max_hearts, hearts + amount)


static func is_game_over(hearts: int) -> bool:
	return hearts <= 0
