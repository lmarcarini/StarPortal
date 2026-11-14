class_name RepairRules
extends RefCounted
## Repairing rooms intruders damaged, pure (M4c-09): a quarter of the room's price and a
## quarter of its build time, sped up by the Workshop like building. A repaired room is back
## as it was (switched on or off as before).
## Bible: docs/content/m4c-incursions.md section 5

## Share of a room's price and build time a repair takes, in percent.
const REPAIR_PERCENT: int = 25


## What repairing [param def] costs, $k.
static func cost_k(def: RoomDef) -> int:
	return def.build_cost_k * REPAIR_PERCENT / 100


## How long repairing [param def] takes, in ticks (at least 1).
static func ticks(def: RoomDef) -> int:
	return maxi(1, def.build_ticks * REPAIR_PERCENT / 100)


## True when some room of [param base] is being repaired.
static func any(base: BaseState) -> bool:
	for room: RoomState in base.rooms:
		if room.repair_ticks_left > 0:
			return true
	return false


## Repairs every room of [param state] under repair by [param step] ticks; a finished one is
## no longer damaged and posts room_repaired.
static func tick(state: GameState, step: int) -> void:
	for room: RoomState in state.base.rooms:
		if room.repair_ticks_left <= 0:
			continue
		room.repair_ticks_left = maxi(0, room.repair_ticks_left - step)
		if room.repair_ticks_left == 0:
			room.damaged = false
			state.events.post(&"room_repaired", [room.id])
