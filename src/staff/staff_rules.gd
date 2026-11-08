class_name StaffRules
extends RefCounted
## Pure rules of staff (docs/content/m26-staff-and-money.md sections 1, 3 and 4): slots per
## room, who works where, beds against headcount, salaries, and why an assignment is refused.
## No side effects, no autoloads: commands, systems and views all read them.
## Bible: docs/content/m26-staff-and-money.md sections 1, 3, 4 and 8

## Refusal: no person with that id.
const UNKNOWN_PERSON: StringName = &"unknown_person"
## Refusal: no room with that id.
const UNKNOWN_ROOM: StringName = &"unknown_room"
## Refusal: the person is still arriving.
const NOT_ON_BASE: StringName = &"not_on_base"
## Refusal: the room is a site or is coming down.
const NOT_BUILT: StringName = &"not_built"
## Refusal: the room has no slots for the person's role (or none at all).
const WRONG_ROLE: StringName = &"wrong_role"
## Refusal: every slot of the room is taken.
const ROOM_FULL: StringName = &"room_full"


## Staff slots of [param room] in [param state]: its RoomDef's staff_slots, 0 for an unknown
## def. A site or a room coming down still has its slots; assign_error() refuses them.
static func slots(state: GameState, room: RoomState) -> int:
	var def: RoomDef = state.room_defs.get(room.def_id)
	return 0 if def == null else def.staff_slots


## The role id [param room]'s slots take, or &"" when it has none.
static func slot_role(state: GameState, room: RoomState) -> StringName:
	var def: RoomDef = state.room_defs.get(room.def_id)
	return &"" if def == null else def.staff_role


## The people assigned to [param room], in roster order.
static func assigned(state: GameState, room: RoomState) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if person.room_id == room.id:
			found.append(person)
	return found


## The people of [param room] at work: assigned() less the injured, who are off work until
## healed and then return (docs/content/m3-beyond-the-ring.md section 4).
static func working(state: GameState, room: RoomState) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in assigned(state, room):
		if not person.is_injured():
			found.append(person)
	return found


## Slots of [param room] still free: slots() less assigned(), at least 0.
static func free_slots(state: GameState, room: RoomState) -> int:
	return maxi(0, slots(state, room) - assigned(state, room).size())


## Beds of the base: every built room not coming down adds its RoomDef's beds (the Control
## Room's crew bunks 6, each Quarters 4).
static func beds(state: GameState) -> int:
	var total: int = 0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and PowerRules.is_standing(room):
			total += def.beds
	return total


## People on the roster, counting those still arriving (their bed is reserved).
static func headcount(state: GameState) -> int:
	return state.staff.people.size()


## Beds taken: people on the roster, counting those still arriving, except lent soldiers, who
## are billeted off-base (docs/content/m3-beyond-the-ring.md section 4).
static func beds_used(state: GameState) -> int:
	return state.staff.people.filter(func(p: PersonState) -> bool: return not p.lent).size()


## Beds left: beds() less beds_used(). Negative only after beds were lost by hand-edited data;
## hiring (card M2.6-06) is refused at 0 or less.
static func beds_free(state: GameState) -> int:
	return beds(state) - beds_used(state)


## [param person]'s salary in $k per 30 days (fixed at hiring).
static func salary_k(person: PersonState) -> int:
	return person.salary_k


## The salary for [param skill] under [param balance]: base + per skill × skill, in $k.
static func salary_for_skill(balance: BalanceConfig, skill: int) -> int:
	return balance.salary_base_k + balance.salary_per_skill_k * skill


## Salaries per 30 days, in $k, charged daily: everyone on the roster, arriving people
## included (m27-daily-rhythm.md section 1).
static func salaries_k(state: GameState) -> int:
	var total: int = 0
	for person: PersonState in state.staff.people:
		total += salary_k(person)
	return total


## Why [param person_id] cannot be assigned to [param room_id], or &"" when they can: an
## unknown person or room, a person still arriving, a site or a room coming down, a room
## without slots of the person's role, or a full room. Assigning someone to the room they
## already work in is allowed (no change).
static func assign_error(
	state: GameState, person_id: StringName, room_id: StringName
) -> StringName:
	var person: PersonState = state.staff.find_person(person_id)
	if person == null:
		return UNKNOWN_PERSON
	var room: RoomState = state.base.find_room(room_id)
	if room == null or not state.room_defs.has(room.def_id):
		return UNKNOWN_ROOM
	if not person.is_on_base(state.clock.tick):
		return NOT_ON_BASE
	if not PowerRules.is_standing(room):
		return NOT_BUILT
	if slots(state, room) == 0 or slot_role(state, room) != person.role:
		return WRONG_ROLE
	if person.room_id != room.id and free_slots(state, room) == 0:
		return ROOM_FULL
	return &""


## Why [param person_id] cannot be unassigned, or &"": only an unknown person. Unassigning
## someone already Unassigned is allowed (no change).
static func unassign_error(state: GameState, person_id: StringName) -> StringName:
	return UNKNOWN_PERSON if state.staff.find_person(person_id) == null else &""


## The Unassigned people on base with role [param role], in roster order.
static func unassigned_of_role(state: GameState, role: StringName) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if person.role == role and not person.is_assigned():
			if person.is_on_base(state.clock.tick):
				found.append(person)
	return found
