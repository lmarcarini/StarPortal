class_name InjuryRules
extends RefCounted
## Injuries and recovery (docs/content/m3-beyond-the-ring.md section 4): light heals in 2 days,
## serious in 8. An injured person is off work (StaffRules.working()) and recovers at 1x;
## in an Infirmary that is on and has room (4 patients) at 2x, or 3x when a medic works in it.
## Patients fill Infirmaries in roster order, rooms in base order. [method injure] and
## [method recover] change only the people they are given: call them from Command.apply() or
## SimSystem.tick() (StaffCareSystem), or from a test.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## Days a light injury takes to heal at 1x.
const LIGHT_DAYS: int = 2
## Days a serious injury takes to heal at 1x.
const SERIOUS_DAYS: int = 8
## Patients one Infirmary holds.
const PATIENTS: int = 4
## Recovery speed resting outside an Infirmary.
const REST_SPEED: int = 1
## Recovery speed in an Infirmary that is on, with room.
const INFIRMARY_SPEED: int = 2
## Recovery speed in such an Infirmary with a medic at work in it.
const MEDIC_SPEED: int = 3
## Skill a seriously injured person counts as in checks.
const SERIOUS_CHECK_SKILL: int = 1


## Injures [param person] with [param injury]; recovery restarts at its full length. A serious
## injury is never made light this way (the worse one stays). NONE does nothing.
static func injure(person: PersonState, injury: PersonState.Injury) -> void:
	if injury == PersonState.Injury.NONE:
		return
	if person.injury == PersonState.Injury.SERIOUS:
		injury = PersonState.Injury.SERIOUS
	person.injury = injury
	var days: int = SERIOUS_DAYS if injury == PersonState.Injury.SERIOUS else LIGHT_DAYS
	person.recovery_left = days * TimeMath.TICKS_PER_DAY


## The skill [param person] counts as in field checks: 1 while seriously injured.
static func check_skill(person: PersonState) -> int:
	if person.injury == PersonState.Injury.SERIOUS:
		return mini(person.skill, SERIOUS_CHECK_SKILL)
	return person.skill


## Recovery speed of every injured person on base in [param state], by person id; people in
## [param away] (on an expedition) are skipped and recover nothing.
static func speeds(state: GameState, away: Array[StringName] = []) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var places: Array[int] = _infirmary_places(state)
	for person: PersonState in state.staff.people:
		if not person.is_injured() or person.id in away:
			continue
		if not person.is_on_base(state.clock.tick):
			continue
		result[person.id] = REST_SPEED if places.is_empty() else places.pop_front()
	return result


## Runs one tick of recovery in [param state] (people in [param away] wait). Returns the
## people healed this tick, in roster order.
static func recover(state: GameState, away: Array[StringName] = []) -> Array[PersonState]:
	var healed: Array[PersonState] = []
	var by_id: Dictionary[StringName, int] = speeds(state, away)
	for person: PersonState in state.staff.people:
		if not by_id.has(person.id):
			continue
		var speed: int = XenoPerks.recovery_speed(state, person, by_id[person.id])
		person.recovery_left = maxi(0, person.recovery_left - speed)
		if person.recovery_left == 0:
			person.injury = PersonState.Injury.NONE
			healed.append(person)
	return healed


## One entry per patient place of every Infirmary that is on, in base order: its recovery
## speed (MEDIC_SPEED with a medic at work in it, else INFIRMARY_SPEED).
static func _infirmary_places(state: GameState) -> Array[int]:
	var places: Array[int] = []
	for room: RoomState in state.base.rooms:
		if room.def_id != ExpeditionUnlock.INFIRMARY_DEF:
			continue
		var def: RoomDef = state.room_defs.get(room.def_id)
		if not PowerRules.is_running(room, def):
			continue
		var medic: bool = StaffRules.working(state, room).any(
			func(p: PersonState) -> bool: return p.role == StartingStaff.MEDIC
		)
		for place: int in PATIENTS:
			places.append(MEDIC_SPEED if medic else INFIRMARY_SPEED)
	return places
