class_name ProgressConditions
extends RefCounted
## The M7 progress conditions, read only: counters (CountAtLeastCondition), what the player
## holds (HeldAtLeastCondition), the share of power drawn (PowerUsageAtLeastCondition) and a
## built room (RoomBuiltCondition). StoryRules.check() hands them here.
## Bible: docs/content/research-and-progression.md sections 6 and 10


## True when [param condition] is one of the progress conditions.
static func handles(condition: ConditionDef) -> bool:
	return (
		condition is CountAtLeastCondition
		or condition is HeldAtLeastCondition
		or condition is PowerUsageAtLeastCondition
		or condition is RoomBuiltCondition
	)


## True when the progress [param condition] holds in [param state].
static func check(state: GameState, condition: ConditionDef) -> bool:
	if condition is CountAtLeastCondition:
		var count: CountAtLeastCondition = condition
		return ProgressCounters.value(state, count.counter) >= count.amount
	if condition is HeldAtLeastCondition:
		var held: HeldAtLeastCondition = condition
		return held_count(state, held.what) >= held.amount
	if condition is PowerUsageAtLeastCondition:
		var supply: float = PowerRules.supply_mw(state)
		var share: float = 0.0 if supply <= 0.0 else PowerRules.allocated_mw(state) / supply
		return share * 100.0 >= float((condition as PowerUsageAtLeastCondition).percent)
	if condition is RoomBuiltCondition:
		var def_id: StringName = (condition as RoomBuiltCondition).room
		for room: RoomState in state.base.rooms:
			if room.def_id == def_id and PowerRules.is_standing(room):
				return true
	return false


## How many of [param what] [param state] holds (HeldAtLeastCondition.WHATS).
static func held_count(state: GameState, what: StringName) -> int:
	match what:
		&"artefacts":
			return state.artefacts.items.size()
		&"hazardous_artefacts":
			var count: int = 0
			for item: ArtefactRecord in state.artefacts.items:
				var def: ArtefactDef = state.artefact_defs.get(item.artefact)
				if def != null and def.hazard_chance_pct > 0:
					count += 1
			return count
		&"specimens":
			return state.artefacts.specimens.size()
		&"addresses":
			return state.address_book.entries.size()
	return 0
