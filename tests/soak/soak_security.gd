class_name SoakSecurity
extends RefCounted
## The soak bot's defence (M4c-17): it builds a Security Post beside the Gate Room, hires a
## soldier when one is on the list, builds a blast door on the way from the Ring to the Power
## Plant, and during an incursion seals or opens the door and orders the squad at random.
## Every command is validated first, so none is refused.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## docs/content/m4c-incursions.md sections 2 and 3

## The bot considers a defence move once every this many ticks, at this minute.
const EVERY_TICKS: int = 60
const AT_TICK: int = 45


## Sends at most one defence command on the bot's security tick while the clock runs and no
## other command waits; true when it sent one.
static func work(simulation: Simulation, rng: RandomNumberGenerator) -> bool:
	var state: GameState = simulation.state
	if state.clock.is_paused or state.clock.tick % EVERY_TICKS != AT_TICK:
		return false
	if simulation.commands.pending_count() > 0:
		return false
	var next: Command = _setup(state)
	if next == null and state.incursion.is_active():
		next = _react(state, rng)
	elif next == null:
		next = _stand_down(state)
	if next == null or not next.validate(state).is_ok:
		return false
	simulation.submit(next)
	return true


static func _setup(state: GameState) -> Command:
	var post: RoomState = _post(state)
	if post == null:
		var gate: RoomState = BaseSpots.gate_room(state.base)
		var target: Rect2i = BaseRules.footprint(gate, state.room_defs[gate.def_id])
		var spot: Vector2i = BaseSpots.nearest_spot(
			state.base, state.room_defs, SquadRules.POST_DEF, gate.level, target
		)
		return PlaceRoomCommand.create(SquadRules.POST_DEF, gate.level, spot)
	if post.is_built() and SquadRules.members(state, post.id).is_empty():
		for candidate: CandidateState in state.recruitment.candidates:
			if candidate.role == SquadRules.SOLDIER:
				return HireCommand.create(candidate.id)
	if state.base.doors.is_empty():
		var cell: Vector3i = _door_spot(state)
		if cell.z >= 0:
			return BuildDoorCommand.create(cell.z, Vector2i(cell.x, cell.y))
	return null


static func _react(state: GameState, rng: RandomNumberGenerator) -> Command:
	var squad: SquadState = null if state.security.squads.is_empty() else state.security.squads[0]
	var door: DoorState = null if state.base.doors.is_empty() else state.base.doors[0]
	match rng.randi_range(0, 2):
		0:
			if door != null:
				var mode: DoorState.Mode = DoorState.Mode.SEALED
				if door.mode == DoorState.Mode.SEALED:
					mode = DoorState.Mode.OPEN
				return SetDoorCommand.create(door.level, door.cell, mode)
		1:
			if squad != null:
				var to: Vector3i = IncursionRules.gate_cell(state)
				return OrderSquadCommand.create(squad.post_room, SquadState.Order.MOVE, to)
		2:
			if squad != null:
				return OrderSquadCommand.create(squad.post_room, SquadState.Order.FALL_BACK)
	return null


static func _stand_down(state: GameState) -> Command:
	for door: DoorState in state.base.doors:
		if door.mode == DoorState.Mode.SEALED:
			return SetDoorCommand.create(door.level, door.cell, DoorState.Mode.OPEN)
	return null


static func _post(state: GameState) -> RoomState:
	for room: RoomState in state.base.rooms:
		if room.def_id == SquadRules.POST_DEF:
			return room
	return null


static func _door_spot(state: GameState) -> Vector3i:
	var plant: RoomState = null
	for room: RoomState in state.base.rooms:
		if room.def_id == ObjectiveRules.POWER_PLANT_DEF:
			plant = room
	if plant == null:
		return Vector3i(-1, -1, -1)
	var from: Vector3i = IncursionRules.gate_cell(state)
	var to := Vector3i(plant.origin.x, plant.origin.y, plant.level)
	for point: Vector3 in BasePaths.find(state.base, from, to, state.room_defs):
		var at := Vector3i(int(point.x), int(point.y), int(point.z))
		if DoorRules.can_build(state, at.z, Vector2i(at.x, at.y)).is_ok:
			return at
	return Vector3i(-1, -1, -1)


## Incursions that ended in [param state]'s Operations Log.
static func incursions_logged(state: GameState) -> int:
	var count: int = 0
	for entry: LogEntry in state.operations_log.entries:
		count += int(entry.kind == &"incursion")
	return count
