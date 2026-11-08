class_name ExpeditionReturns
extends RefCounted
## What a team brings back on its return (docs/content/m3-beyond-the-ring.md section 4, What
## comes back), applied by ExpeditionSystem. A Survey makes the world SURVEYED (Confidence +3
## the first time, as "New world surveyed"), raises the threat to GOOD with its reasons and the
## Biohazard to GOOD, files a survey report and, on ruins, sometimes (30%, seeded) an address.
## A Recover with no wasted day marks its target RECOVERED and files the object; recovering
## STILLWATER's anchor sets the flag [constant ANCHOR_FLAG]. A failed Recover leaves the target
## recoverable. Call only from SimSystem.tick().
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Source id of every report fact a team raises.
const SOURCE: StringName = &"team"
## Confidence of a team survey, in tenths: +3.
const SURVEY_CHANGE: int = 30
## Chance in percent that a survey of ruins finds an address.
const RUINS_ADDRESS_PERCENT: int = 30
## The anchor: STILLWATER's iron object (docs/content/m3-beyond-the-ring.md section 3).
const ANCHOR_WORLD_ID: StringName = &"world_stillwater"
const ANCHOR_TARGET_ID: StringName = &"iron_object"
## Flag set when a team recovers the anchor.
const ANCHOR_FLAG: StringName = &"anchor_recovered"


## Applies what the team of [param state]'s expedition brings back; true when the objective
## succeeded. [param rng] is the expedition's seeded generator.
static func apply(state: GameState, rng: RandomNumberGenerator) -> bool:
	var plan: ExpeditionState = state.expedition
	if plan.day_results.has(ExpeditionState.DAY_WASTED) and _is_recover(plan):
		return false
	match plan.objective:
		ExpeditionState.Objective.SURVEY:
			_survey(state, plan.world_id, rng)
		ExpeditionState.Objective.RECOVER:
			_recover(state, plan.world_id, plan.target_id)
	return true


## True when [param target_id] on [param world_id] is the anchor.
static func is_anchor(world_id: StringName, target_id: StringName) -> bool:
	return world_id == ANCHOR_WORLD_ID and target_id == ANCHOR_TARGET_ID


static func _is_recover(plan: ExpeditionState) -> bool:
	return plan.objective == ExpeditionState.Objective.RECOVER


static func _survey(state: GameState, world_id: StringName, rng: RandomNumberGenerator) -> void:
	if WorldProgress.raise_status(state, world_id, WorldsState.WorldStatus.SURVEYED):
		ConfidenceEvents.raise(
			state, ConfidenceRules.SURVEYED, world_id, Vector2i(1, SURVEY_CHANGE)
		)
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts != null:
		WorldProgress.raise_threat_good(state, world_id, SOURCE, facts)
	WorldProgress.raise_fact(
		state,
		WorldProgress.FactChange.create(
			world_id, WorldReport.Fact.BIOHAZARD, WorldReport.Confidence.GOOD, SOURCE
		)
	)
	state.expedition.add_document("survey_report", world_id, &"", state.clock.tick)
	var roll: int = rng.randi_range(0, 99)
	if facts != null and facts.structures == WorldDef.Structures.RUINS:
		if roll < RUINS_ADDRESS_PERCENT:
			_find_address(state, world_id)


## Records the address a survey of ruins found: the next nearest world after those the console
## and its older log list.
static func _find_address(state: GameState, world_id: StringName) -> void:
	var galaxy: GalaxyCatalogue = state.galaxy
	var known: int = (
		ConsoleLog.entry_count(world_id) + MothRules.older_log_worlds(world_id, galaxy).size()
	)
	var nearest: Array[StringName] = ConsoleLog.nearest_worlds(world_id, galaxy, known + 1)
	if nearest.size() <= known:
		return
	var key: String = galaxy.address_of(nearest[known], galaxy.home().origin_glyph).key()
	if state.address_book.find(key) != null:
		return
	state.address_book.entries.push_front(
		AddressEntry.create(key, AddressEntry.Source.DOCUMENT, world_id)
	)
	state.events.post(&"address_book_changed", [])


static func _recover(state: GameState, world_id: StringName, target_id: StringName) -> void:
	if not WorldProgress.raise_target(state, world_id, target_id, TargetStates.State.RECOVERED):
		return
	state.expedition.add_document("object", world_id, target_id, state.clock.tick)
	if is_anchor(world_id, target_id):
		state.flags[ANCHOR_FLAG] = true
