class_name ExpeditionFieldDay
extends RefCounted
## One field day of the team away (docs/content/m3-beyond-the-ring.md section 4, Risk model):
## one field event, drawn from FieldEvents by objective, biome and true threat, resolves at the
## check-in that ends its day (for the last day, the return). The team's best person in the
## event's role rolls (FieldCheck). Success gives the event's finding or nothing bad; failure
## its setback: a wasted day, a light or serious injury to the roller (a medic on the team
## turns a serious one into a light one), or a missed check-in. Posts
## field_event_resolved(world id, event id, outcome, roller name) with outcome "finding" or a
## setback name (FieldEventDef.SETBACK_NAMES). Call only from SimSystem.tick().
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Event posted for each field event resolved.
const EVENT: StringName = &"field_event_resolved"
## Outcome of a passed check.
const FINDING: String = "finding"


## The result (an ExpeditionState.DAY_RESULTS entry) of field day [param _day] (0-based) of
## [param state]'s expedition, drawn with [param rng], the expedition's seeded generator.
static func resolve(state: GameState, _day: int, rng: RandomNumberGenerator) -> String:
	var plan: ExpeditionState = state.expedition
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, plan.world_id)
	if facts == null:
		return ExpeditionState.DAY_OK
	var def: FieldEventDef = FieldEvents.draw(plan.objective, facts, rng)
	if def == null:
		return ExpeditionState.DAY_OK
	var members: Array[PersonState] = _members(state)
	var roller: PersonState = FieldCheck.roller(members, def.role)
	var percent: int = FieldCheck.chance(
		FieldCheck.skill_of(roller), FieldCheck.difficulty(def, facts)
	)
	var outcome: String = FINDING
	if not FieldCheck.succeeds(rng.randi_range(0, 99), percent):
		outcome = _apply_setback(def.setback, roller, members)
	var person_name: String = "" if roller == null else roller.name
	state.events.post(EVENT, [plan.world_id, def.id, outcome, person_name])
	return _day_result(outcome)


## Applies [param setback] to [param roller] (if any); returns the outcome name.
static func _apply_setback(
	setback: FieldEventDef.Setback, roller: PersonState, members: Array[PersonState]
) -> String:
	if setback == FieldEventDef.Setback.SERIOUS and _has_medic(members):
		setback = FieldEventDef.Setback.LIGHT
	if roller != null and setback == FieldEventDef.Setback.LIGHT:
		InjuryRules.injure(roller, PersonState.Injury.LIGHT)
	elif roller != null and setback == FieldEventDef.Setback.SERIOUS:
		InjuryRules.injure(roller, PersonState.Injury.SERIOUS)
	return FieldEventDef.SETBACK_NAMES[setback]


static func _day_result(outcome: String) -> String:
	match outcome:
		"wasted":
			return ExpeditionState.DAY_WASTED
		"missed":
			return ExpeditionState.DAY_MISSED
	return ExpeditionState.DAY_OK


static func _has_medic(members: Array[PersonState]) -> bool:
	return members.any(func(p: PersonState) -> bool: return p.role == StartingStaff.MEDIC)


static func _members(state: GameState) -> Array[PersonState]:
	var members: Array[PersonState] = []
	for person_id: StringName in state.expedition.member_ids():
		var person: PersonState = state.staff.find_person(person_id)
		if person != null:
			members.append(person)
	return members
