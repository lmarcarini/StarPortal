class_name StaffChanges
extends RefCounted
## The only code that moves people between rooms; call it from Command.apply() or
## SimSystem.tick() only. Each change posts staff_changed(reason, room def id, count) through
## the outbox. Staff never change power in M2.6, so nothing here touches RoomState.revision.
## Bible: docs/content/m26-staff-and-money.md sections 3 and 7

## staff_changed reason: a player assignment (count 1).
const ASSIGNED: StringName = &"assigned"
## staff_changed reason: a player unassignment (count 1; the room the person left).
const UNASSIGNED: StringName = &"unassigned"
## staff_changed reason: the first room of its type took the waiting crew (logged).
const AUTO_ASSIGNED: StringName = &"auto_assigned"
## staff_changed reason: a room coming down released its people (logged).
const RELEASED: StringName = &"released"


## Puts [param person] in [param room] (validated with StaffRules.assign_error()).
static func assign(state: GameState, person: PersonState, room: RoomState) -> void:
	if person.room_id == room.id:
		return
	person.room_id = room.id
	state.events.post(&"staff_changed", [ASSIGNED, room.def_id, 1])


## Makes [param person] Unassigned.
static func unassign(state: GameState, person: PersonState) -> void:
	if not person.is_assigned():
		return
	var room: RoomState = state.base.find_room(person.room_id)
	person.room_id = &""
	var def_id: StringName = &"" if room == null else room.def_id
	state.events.post(&"staff_changed", [UNASSIGNED, def_id, 1])


## Makes everyone in [param rooms] Unassigned, posting one RELEASED event per room that had
## people (demolition: m26 card M2.6-05).
static func release(state: GameState, rooms: Array[RoomState]) -> void:
	for room: RoomState in rooms:
		var people: Array[PersonState] = StaffRules.assigned(state, room)
		for person: PersonState in people:
			person.room_id = &""
		if not people.is_empty():
			state.events.post(&"staff_changed", [RELEASED, room.def_id, people.size()])


## Called when [param room] finishes building (ConstructionSystem). When its def is still in
## StaffState.auto_assign, the def leaves the list and the Unassigned people on base of the
## room's role fill its slots in roster order (section 7: "Research Lab staffed: 2
## scientists."). Later rooms of that type are staffed by hand.
static func auto_assign(state: GameState, room: RoomState) -> void:
	if not room.def_id in state.staff.auto_assign:
		return
	state.staff.auto_assign.erase(room.def_id)
	var waiting: Array[PersonState] = StaffRules.unassigned_of_role(
		state, StaffRules.slot_role(state, room)
	)
	var count: int = mini(waiting.size(), StaffRules.free_slots(state, room))
	for index: int in count:
		waiting[index].room_id = room.id
	if count > 0:
		state.events.post(&"staff_changed", [AUTO_ASSIGNED, room.def_id, count])
