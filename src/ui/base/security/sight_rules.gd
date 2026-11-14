class_name SightRules
extends RefCounted
## What the cameras see of intruders (M4c-11), pure: a group is visible while it is in a
## room that is on, in a corridor next to a room that is on, or in reach of a squad. Power is
## sight: a room switched off (or damaged) is blind.
## Bible: docs/content/m4c-incursions.md section 7

## Ticks a last-seen marker takes to fade.
const FADE_TICKS: int = 20
const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## True when [param group] of [param state] can be seen now.
static func visible(state: GameState, group: IntruderGroup) -> bool:
	var at: Vector3i = group.pos()
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	var room: RoomState = cells.get(at)
	if room == null:
		return false
	if not BasePaths.HALLS.has(room.def_id) and _lit(state, room):
		return true
	if BasePaths.HALLS.has(room.def_id):
		for step: Vector2i in _STEPS:
			var other: RoomState = cells.get(Vector3i(at.x + step.x, at.y + step.y, at.z))
			if other != null and other != room and not BasePaths.HALLS.has(other.def_id):
				if _lit(state, other):
					return true
	for squad: SquadState in state.security.squads:
		var reach: int = state.balance.combat_reach_cells
		if CombatRules.in_reach(squad.pos, at, state.base, state.room_defs, reach):
			return true
	return false


static func _lit(state: GameState, room: RoomState) -> bool:
	var def: RoomDef = state.room_defs.get(room.def_id)
	return PowerRules.is_running(room, def)
