class_name StartingBase
extends RefCounted
## Builds the base a new game starts with (docs/content/m25-lean-start.md section 1): one
## level, Level 1, with a corridor spine one row across it, the Gate Room just above the spine
## and the Control Room and the diesel Power Plant just below it, all built and switched on.
## Nothing else; no cell is reserved. Pure: depends only on the BalanceConfig. Rooms are added
## with BaseState.add_room(), so the power cache (PowerRules.totals()) sees them.
## Bible: game-design.md#base-building-and-power, docs/content/m25-lean-start.md section 1

## The Gate Room's def id; the Ring sits on Level 1.
const GATE_ROOM_DEF: StringName = &"room_gate"
## The Capacitor Bank's def id.
const CAPACITOR_BANK_DEF: StringName = &"room_capacitor_bank"
## Corridor def id: one cell per room.
const CORRIDOR_DEF: StringName = &"room_corridor"
## Lift def id: one 2 × 2 room on every level, at the same cells.
const LIFT_DEF: StringName = &"room_lift"
## The level everything starts on.
const START_LEVEL: int = 1
## Row of the corridor spine; it runs across the whole level.
const SPINE_ROW: int = 10
## The pre-built rooms on Level 1, as [def id, origin]; each touches the spine.
const ROOMS: Array = [
	[&"room_gate", Vector2i(14, 2)],
	[&"room_control", Vector2i(15, 11)],
	[&"room_power_plant", Vector2i(6, 11)],
]


## Returns the starting BaseState for [param balance]: its grid size, its starting levels
## (all dug; M2.5 starts with one) and the rooms of section 1 on Level 1, every room built and
## switched on.
static func build(balance: BalanceConfig) -> BaseState:
	assert(balance != null, "StartingBase.build() needs a balance")
	var base := BaseState.new()
	base.grid_size = balance.base_grid_size
	for index: int in maxi(1, balance.starting_levels):
		base.levels.append(LevelState.new())
	for entry: Array in ROOMS:
		var def_id: StringName = entry[0]
		var origin: Vector2i = entry[1]
		base.add_room(def_id, START_LEVEL, origin)
	for column: int in base.grid_size.x:
		base.add_room(CORRIDOR_DEF, START_LEVEL, Vector2i(column, SPINE_ROW))
	return base
