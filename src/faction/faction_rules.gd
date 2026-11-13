class_name FactionRules
extends RefCounted
## Pure rules of faction standing: read it, change it with a cause, derive the attitude and
## meet a faction. The Committee's standing is Committee Confidence (whole points), changed
## through ConfidenceEvents with a story cause, so there is one system, not two.
## Bible: docs/content/m4-core-systems.md section 2

## Derived from standing, never stored.
enum Attitude { HOSTILE, UNFRIENDLY, NEUTRAL, FRIENDLY, ALLIED }

## Id of the Committee faction (its FactionDef has uses_confidence).
const COMMITTEE: StringName = &"faction_committee"
## Standing range.
const MIN: int = -100
const MAX: int = 100
## Causes kept per faction.
const CAUSES_KEPT: int = 10
## Lowest standing of Unfriendly, Neutral, Friendly and Allied.
const BANDS: Array[int] = [-49, -9, 25, 60]
## Lowest Confidence (whole points) of the Committee's Neutral and Friendly.
const COMMITTEE_BANDS: Array[int] = [30, 70]
## Text key of each attitude, in enum order.
const ATTITUDE_KEYS: Array[StringName] = [
	&"ATTITUDE_HOSTILE",
	&"ATTITUDE_UNFRIENDLY",
	&"ATTITUDE_NEUTRAL",
	&"ATTITUDE_FRIENDLY",
	&"ATTITUDE_ALLIED",
]


## Standing of [param faction]: the Committee's Confidence in whole points, a known faction's
## saved standing, 0 for an unknown one.
static func standing(state: GameState, faction: StringName) -> int:
	if faction == COMMITTEE:
		return ConfidenceRules.whole(state.committee.confidence)
	return state.factions.standing.get(faction, 0)


## True when [param faction] has a standing (the Committee always does).
static func is_known(state: GameState, faction: StringName) -> bool:
	return faction == COMMITTEE or state.factions.standing.has(faction)


## The attitude of [param faction] from its standing (the Committee uses its own bands).
static func attitude(state: GameState, faction: StringName) -> Attitude:
	var value: int = standing(state, faction)
	if faction == COMMITTEE:
		if value >= COMMITTEE_BANDS[1]:
			return Attitude.FRIENDLY
		return Attitude.NEUTRAL if value >= COMMITTEE_BANDS[0] else Attitude.UNFRIENDLY
	var result: int = Attitude.HOSTILE
	for band: int in BANDS:
		if value >= band:
			result += 1
	return result as Attitude


## Text key of [param value].
static func attitude_key(value: Attitude) -> StringName:
	return ATTITUDE_KEYS[value]


## Moves the standing of [param faction] by [param delta], clamped to −100..100, with
## [param cause_key] (a translation key) as the reason; keeps the last ten causes and posts
## standing_changed. The Committee moves Confidence with a story cause instead. Returns the
## change applied; 0 for an unknown faction or no change.
static func change(state: GameState, faction: StringName, delta: int, cause_key: StringName) -> int:
	if not is_known(state, faction) or delta == 0:
		return 0
	if faction == COMMITTEE:
		return _change_confidence(state, delta, cause_key)
	var before: int = standing(state, faction)
	var after: int = clampi(before + delta, MIN, MAX)
	var applied: int = after - before
	if applied == 0:
		return 0
	state.factions.standing[faction] = after
	var causes: Array = state.factions.causes.get(faction, [])
	causes.append({"tick": state.clock.tick, "delta": applied, "key": cause_key})
	while causes.size() > CAUSES_KEPT:
		causes.pop_front()
	state.factions.causes[faction] = causes
	state.events.post(&"standing_changed", [faction, after, applied])
	return applied


## Marks [param faction] met (once): posts faction_met, which writes a Log line. Returns true
## the first time.
static func meet(state: GameState, faction: StringName) -> bool:
	if faction.is_empty() or state.factions.met.has(faction):
		return false
	state.factions.met.append(faction)
	state.events.post(&"faction_met", [faction])
	return true


static func _change_confidence(state: GameState, delta: int, cause_key: StringName) -> int:
	var before: int = state.committee.confidence
	var change_tenths: int = delta * ConfidenceRules.TENTHS
	var after: int = ConfidenceRules.changed(before, change_tenths)
	if after == before:
		return 0
	ConfidenceEvents.raise(state, ConfidenceRules.STORY, cause_key, Vector2i(1, after - before))
	var applied: int = ConfidenceRules.whole(after) - ConfidenceRules.whole(before)
	state.events.post(&"standing_changed", [COMMITTEE, ConfidenceRules.whole(after), applied])
	return applied
