class_name FeedIntruders
extends RefCounted
## Intruders as a camera feed shows them (M4c-13): the standing units of every group in the
## room, only where SightRules sees them, spread across the floor.
## Bible: docs/content/m4c-incursions.md section 7


## FeedPeople for the visible intruders in [param room] of [param state].
static func in_room(state: GameState, room: RoomState) -> Array[FeedPerson]:
	var found: Array[FeedPerson] = []
	if not state.incursion.is_active():
		return found
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for group: IntruderGroup in state.incursion.groups:
		if cells.get(group.pos()) != room or not SightRules.visible(state, group):
			continue
		var up: Array[UnitState] = group.standing()
		for index: int in up.size():
			var at := Vector2(0.25 + 0.5 * float(index) / maxf(1.0, float(up.size())), 0.35)
			found.append(FeedPerson.create(&"intruder", at))
	return found


## True when a squad and a group stand in [param room] together (a fight on camera).
static func fighting(state: GameState, room: RoomState) -> bool:
	if not state.incursion.is_active():
		return false
	var has_intruders: bool = false
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for group: IntruderGroup in state.incursion.groups:
		has_intruders = has_intruders or cells.get(group.pos()) == room
	return has_intruders and IntruderRules.contested(state, room.id)
