class_name StaffPicks
extends RefCounted
## The choices offered when assigning (docs/content/m26-staff-and-money.md section 6): the
## rooms a person can go to (a free slot of their role; full rooms and their own room are not
## offered), and the Unassigned people on base who can fill a room's empty slot. Read from
## StaffRules; pure, never changes the state.
## Bible: docs/content/m26-staff-and-money.md section 6


## The rooms of [param state] [param person] can be assigned to now, in base order.
static func rooms_for(state: GameState, person: PersonState) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		if room.id != person.room_id and StaffRules.slots(state, room) > 0:
			if StaffRules.assign_error(state, person.id, room.id).is_empty():
				found.append(room)
	return found


## The Unassigned people on base who can fill an empty slot of [param room], in roster order.
static func people_for(state: GameState, room: RoomState) -> Array[PersonState]:
	if StaffRules.free_slots(state, room) <= 0 or not PowerRules.is_standing(room):
		return []
	return StaffRules.unassigned_of_role(state, StaffRules.slot_role(state, room))
