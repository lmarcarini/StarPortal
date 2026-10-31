class_name EconomySystem
extends SimSystem
## Minimal M2 money. At each month-end it pays the fixed allocation and charges every built
## room's upkeep (half, rounded down, for a room switched off), then posts budget_changed.
## Rooms under construction pay nothing. A lift is one RoomState per level at the same cells,
## but one shaft pays its upkeep once.
## Bible: docs/content/m2-base.md section 5

## Defs whose rooms stack into one shaft across levels: same def and origin pay once.
const SHAFT_DEFS: Array[StringName] = [&"room_lift"]

var _balance: BalanceConfig
## RoomDef by id.
var _room_defs: Dictionary[StringName, RoomDef] = {}


func _init(balance: BalanceConfig, room_defs: Array[RoomDef]) -> void:
	_balance = balance
	for def: RoomDef in room_defs:
		_room_defs[def.id] = def


## Returns the system id, &"economy".
func get_id() -> StringName:
	return &"economy"


## Nothing happens per tick.
func tick(_state: GameState) -> void:
	pass


## Adds the allocation, subtracts the upkeep and posts budget_changed(new balance).
func on_month(state: GameState) -> void:
	var upkeep_k: int = monthly_upkeep_k(state.base, _room_defs)
	state.budget.funds_k += _balance.monthly_allocation_k - upkeep_k
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Total monthly upkeep of [param base]'s built rooms, in $k, with [param room_defs] by id:
## a room switched off pays half (rounded down), a lift shaft pays once
## and unknown defs pay nothing.
static func monthly_upkeep_k(base: BaseState, room_defs: Dictionary[StringName, RoomDef]) -> int:
	var total: int = 0
	var shafts_seen: Dictionary[String, bool] = {}
	for room: RoomState in base.rooms:
		var def: RoomDef = room_defs.get(room.def_id)
		if def == null or not room.is_built():
			continue
		if room.def_id in SHAFT_DEFS:
			var shaft: String = "%s@%s" % [room.def_id, room.origin]
			if shafts_seen.has(shaft):
				continue
			shafts_seen[shaft] = true
		total += def.upkeep_k if room.powered_on else def.upkeep_k / 2
	return total
