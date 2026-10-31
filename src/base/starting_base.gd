class_name StartingBase
extends RefCounted
## Builds the base a new game starts with (docs/content/m2-base.md section 2): the starting
## levels, all dug, each with a corridor spine and the lift shaft, the Power Plant and two
## Quarters on Level 1, the Archive on Level 2, and the Gate Room, Control Room and the
## capacitor alcove (left free) on Level 3. Pure: depends only on the BalanceConfig.
## Bible: game-design.md#base-building-and-power, docs/content/m2-base.md

## The Gate Room's def id; the Ring sits on the deepest starting level.
const GATE_ROOM_DEF: StringName = &"room_gate"
## The Capacitor Bank's def id; its footprint is the capacitor alcove's.
const CAPACITOR_BANK_DEF: StringName = &"room_capacitor_bank"
## Corridor def id: one cell per room.
const CORRIDOR_DEF: StringName = &"room_corridor"
## Lift def id: one 2 × 2 room on every level, at the same cells.
const LIFT_DEF: StringName = &"room_lift"
## Top-left cell of the lift shaft on every level.
const LIFT_ORIGIN: Vector2i = Vector2i(32, 14)
## Row of the corridor spine on every level, and its first and last column.
const SPINE_ROW: int = 15
const SPINE_FIRST: int = 4
const SPINE_LAST: int = 31
## Rooms per level, as [def id, origin]; the deepest level is the Gate level.
const ROOMS_LEVEL_1: Array = [
	[&"room_power_plant", Vector2i(6, 11)],
	[&"room_quarters", Vector2i(12, 13)],
	[&"room_quarters", Vector2i(16, 13)],
]
const ROOMS_LEVEL_2: Array = [[&"room_archive", Vector2i(12, 12)]]
const ROOMS_GATE_LEVEL: Array = [
	[&"room_gate", Vector2i(14, 4)],
	[&"room_control", Vector2i(15, 12)],
]
## Extra corridor cells on the Gate level, as (column, first row, last row): one branch to the
## Gate Room's west wall and one beside the capacitor alcove.
const GATE_LEVEL_BRANCHES: Array[Vector3i] = [Vector3i(13, 8, 14), Vector3i(25, 10, 14)]


## Returns the starting BaseState for [param balance]: its grid size and starting levels, every
## room built and switched on.
static func build(balance: BalanceConfig) -> BaseState:
	assert(balance != null, "StartingBase.build() needs a balance")
	var base := BaseState.new()
	base.grid_size = balance.base_grid_size
	for index: int in balance.starting_levels:
		base.levels.append(LevelState.new())
	for level: int in range(1, balance.starting_levels + 1):
		_add_rooms(base, level, _rooms_for(level, balance.starting_levels))
		for column: int in range(SPINE_FIRST, SPINE_LAST + 1):
			base.add_room(CORRIDOR_DEF, level, Vector2i(column, SPINE_ROW))
		base.add_room(LIFT_DEF, level, LIFT_ORIGIN)
	for branch: Vector3i in GATE_LEVEL_BRANCHES:
		for row: int in range(branch.y, branch.z + 1):
			base.add_room(CORRIDOR_DEF, balance.starting_levels, Vector2i(branch.x, row))
	return base


## Returns the capacitor alcove's cells: the balance's alcove origin and [param bank]'s
## footprint, unturned. The starting base leaves it free.
static func alcove(balance: BalanceConfig, bank: RoomDef) -> Rect2i:
	return Rect2i(balance.capacitor_alcove_origin, bank.size_cells)


static func _rooms_for(level: int, deepest: int) -> Array:
	if level == deepest:
		return ROOMS_GATE_LEVEL
	if level == 1:
		return ROOMS_LEVEL_1
	if level == 2:
		return ROOMS_LEVEL_2
	return []


static func _add_rooms(base: BaseState, level: int, entries: Array) -> void:
	for entry: Array in entries:
		var def_id: StringName = entry[0]
		var origin: Vector2i = entry[1]
		base.add_room(def_id, level, origin)
