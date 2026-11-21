class_name DoorRules
extends RefCounted
## Blast door rules, pure (M4c-04): where a door may be built, finding one, building them
## and dropping doors whose corridor is gone.
## Bible: docs/content/m4c-incursions.md section 4

## Percent of an unbuilt door's cost refunded on removal, as a cancelled site.
const CANCEL_REFUND_PERCENT: int = 75
const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## The door of [param base] at [param cell] on [param level], or null.
static func find(base: BaseState, level: int, cell: Vector2i) -> DoorState:
	for door: DoorState in base.doors:
		if door.level == level and door.cell == cell:
			return door
	return null


## Whether a door may be built at [param cell] on [param level] of [param state]: its plan
## known (Blast doors, E10; &"needs_research"), on a built corridor cell (&"not_corridor"),
## not beside the Gate Room (&"gate_doorway"), none there
## already (&"door_exists").
static func can_build(state: GameState, level: int, cell: Vector2i) -> CommandResult:
	if not ResearchPerks.has(state, ResearchPerks.BLAST_DOOR):
		return CommandResult.fail(&"needs_research", "blast_doors")
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	var room: RoomState = cells.get(Vector3i(cell.x, cell.y, level))
	if room == null or room.def_id != StartingBase.CORRIDOR_DEF:
		return CommandResult.fail(&"not_corridor")
	for step: Vector2i in _STEPS:
		var other: RoomState = cells.get(Vector3i(cell.x + step.x, cell.y + step.y, level))
		if other != null and other.def_id == StartingBase.GATE_ROOM_DEF:
			return CommandResult.fail(&"gate_doorway")
	if find(state.base, level, cell) != null:
		return CommandResult.fail(&"door_exists")
	return CommandResult.ok()


## What removing [param door] refunds: 75% while building, nothing once built.
static func refund_k(door: DoorState) -> int:
	return 0 if door.is_built() else door.paid_k * CANCEL_REFUND_PERCENT / 100


## Builds every door of [param state] by [param step] ticks; posts door_changed when one
## finishes.
static func tick_builds(state: GameState, step: int) -> void:
	for door: DoorState in state.base.doors:
		if door.is_built():
			continue
		door.build_ticks_left = maxi(door.build_ticks_left - step, 0)
		if door.is_built():
			state.events.post(&"door_changed", [door.level, door.cell])


## Removes the doors of [param state] no longer on a built corridor (the corridor was
## demolished), posting door_changed for each.
static func drop_orphans(state: GameState) -> void:
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for door: DoorState in state.base.doors.duplicate():
		var room: RoomState = cells.get(door.pos())
		if room == null or room.def_id != StartingBase.CORRIDOR_DEF:
			state.base.doors.erase(door)
			state.events.post(&"door_changed", [door.level, door.cell])
