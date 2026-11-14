class_name InstallationRules
extends RefCounted
## Installations, pure (M4c-18): where one may be fitted, building them like small sites
## (Workshop speed, nothing during an incursion), refunds as rooms (75% while building, 50%
## built), and whether one is active (built, its room on and not damaged; a door's while the
## door stands).
## Bible: docs/content/m4c-incursions.md section 6

## Percent refunded removing an unbuilt and a built installation.
const CANCEL_REFUND_PERCENT: int = 75
const REMOVE_REFUND_PERCENT: int = 50


## Whether [param def_id] may be fitted to room [param room] of [param state]
## (null for a door: then [param door] is the host): ok, or &"unknown_installation",
## &"not_researched", &"wrong_host", &"room_not_built", &"host_full", &"insufficient_funds".
static func can_install(
	state: GameState, def_id: StringName, room: RoomState, door: DoorState = null
) -> CommandResult:
	var def: InstallationDef = state.installation_defs.get(def_id)
	if def == null:
		return CommandResult.fail(&"unknown_installation")
	if not def.requires_research.is_empty() and not state.research.done.has(def.requires_research):
		return CommandResult.fail(&"not_researched")
	var fits: bool = def.fits_door() if room == null else def.fits_room(room.def_id)
	if not fits or (room == null and door == null):
		return CommandResult.fail(&"wrong_host")
	var built: bool = room.is_built() if room != null else door.is_built()
	if not built:
		return CommandResult.fail(&"room_not_built")
	var items: Array[InstallationState] = room.installations if room != null else door.installations
	if count(items, def_id) >= def.max_per_host:
		return CommandResult.fail(&"host_full")
	var funds_error: StringName = state.budget.spend_error(def.cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error)
	return CommandResult.ok()


## How many of [param def_id] [param items] holds.
static func count(items: Array[InstallationState], def_id: StringName) -> int:
	var found: int = 0
	for item: InstallationState in items:
		if item.def == def_id:
			found += 1
	return found


## The first of [param def_id] in [param items], or null.
static func find(items: Array[InstallationState], def_id: StringName) -> InstallationState:
	for item: InstallationState in items:
		if item.def == def_id:
			return item
	return null


## A new site of [param def] (paid in full).
static func create(def: InstallationDef) -> InstallationState:
	var item := InstallationState.new()
	item.def = def.id
	item.paid_k = def.cost_k
	item.health = def.health
	item.build_ticks_left = maxi(1, def.build_ticks)
	return item


## What removing [param item] refunds.
static func refund_k(item: InstallationState) -> int:
	var percent: int = REMOVE_REFUND_PERCENT if item.is_built() else CANCEL_REFUND_PERCENT
	return item.paid_k * percent / 100


## True when room [param room_id] of [param state] has a built [param def_id] and is running.
static func active(state: GameState, room_id: StringName, def_id: StringName) -> bool:
	var room: RoomState = state.base.find_room(room_id)
	if room == null:
		return false
	var item: InstallationState = find(room.installations, def_id)
	if item == null or not item.is_built():
		return false
	var room_def: RoomDef = state.room_defs.get(room.def_id)
	return PowerRules.is_running(room, room_def)


## True when some installation of [param state] is still being built.
static func any_building(state: GameState) -> bool:
	for room: RoomState in state.base.rooms:
		for item: InstallationState in room.installations:
			if not item.is_built():
				return true
	for door: DoorState in state.base.doors:
		for item: InstallationState in door.installations:
			if not item.is_built():
				return true
	return false


## Builds every installation site of [param state] by [param step] ticks; posts
## installation_changed with the host's id (a door's "door_<level>_<x>_<y>") when one is done.
static func tick(state: GameState, step: int) -> void:
	for room: RoomState in state.base.rooms:
		if room.is_built() and _tick_items(room.installations, step):
			state.events.post(&"installation_changed", [room.id])
	for door: DoorState in state.base.doors:
		if door.is_built() and _tick_items(door.installations, step):
			state.events.post(&"installation_changed", [door_key(door)])


## The id a door's installations are reported under.
static func door_key(door: DoorState) -> StringName:
	return StringName("door_%d_%d_%d" % [door.level, door.cell.x, door.cell.y])


static func _tick_items(items: Array[InstallationState], step: int) -> bool:
	var finished: bool = false
	for item: InstallationState in items:
		if item.is_built():
			continue
		item.build_ticks_left = maxi(0, item.build_ticks_left - step)
		finished = finished or item.is_built()
	return finished
