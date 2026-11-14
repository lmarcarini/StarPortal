class_name CivilianRules
extends RefCounted
## Civilians during an incursion, pure (M4c-09): they stop work and shelter in place (the
## systems pause); a civilian in a room an intruder group enters is hit on a 1 in 4 roll,
## once per group per room: a light injury, serious if already hurt. Soldiers fight instead.
## Bible: docs/content/m4c-incursions.md section 5

## One in this many civilians in a room a group enters is hit.
const HIT_ONE_IN: int = 4


## Checks every group of [param state] that stands in a room it has not entered before.
static func hit(state: GameState, rng: RandomNumberGenerator) -> void:
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for group: IntruderGroup in state.incursion.groups:
		var room: RoomState = cells.get(group.pos())
		if room == null or BasePaths.HALLS.has(room.def_id) or group.visited.has(room.id):
			continue
		group.visited.append(room.id)
		for person: PersonState in _civilians_in(state, room.id):
			if rng.randi_range(1, HIT_ONE_IN) != 1:
				continue
			var worse: PersonState.Injury = PersonState.Injury.LIGHT
			if person.is_injured():
				worse = PersonState.Injury.SERIOUS
			InjuryRules.injure(person, worse)
			var hurt: Array = state.incursion.report.get("hurt", [])
			hurt.append(String(person.id))
			state.incursion.report["hurt"] = hurt


static func _civilians_in(state: GameState, room_id: StringName) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if person.room_id == room_id and person.role != SquadRules.SOLDIER:
			if person.is_on_base(state.clock.tick) and not person.lent:
				found.append(person)
	return found
