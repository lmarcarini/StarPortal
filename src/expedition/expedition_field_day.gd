class_name ExpeditionFieldDay
extends RefCounted
## One field day of the team away (docs/content/m3-beyond-the-ring.md section 4, Risk model):
## resolved at the check-in that ends it (for the last day, the return). In this card every day
## passes without incident; field events (card M3-11) draw and roll the day's event here and
## return its outcome. Call only from SimSystem.tick().
## Bible: docs/content/m3-beyond-the-ring.md section 4


## The result (an ExpeditionState.DAY_RESULTS entry) of field day [param _day] (0-based) of
## [param _state]'s expedition, drawn with [param _rng], the expedition's seeded generator.
static func resolve(_state: GameState, _day: int, _rng: RandomNumberGenerator) -> String:
	return ExpeditionState.DAY_OK
