class_name LiftShafts
extends RefCounted
## Lift shafts across levels (docs/content/m25-lean-start.md section 2). A lift built before a
## dig extends into the new level when the dig finishes, as one lift segment
## (BalanceConfig.lift_segment_cost_k, lift_segment_ticks), charged and started automatically.
## A segment is its own site, takes no building slot and is cancelled like any site. Short of
## funds it is refused with lift_segment_refused(level, cost k); the player can then build it
## from the palette by placing a lift on the shaft (PlaceRoomCommand), at the segment price.
## Bible: docs/content/m25-lean-start.md section 2


## True when [param room] of [param base] is a lift segment: a lift whose shaft (lifts at the
## same origin on other levels) belongs to another site.
static func is_segment(base: BaseState, room: RoomState) -> bool:
	if room.def_id != StartingBase.LIFT_DEF:
		return false
	for other: RoomState in base.rooms:
		if (
			other.def_id == StartingBase.LIFT_DEF
			and other.origin == room.origin
			and other.level != room.level
			and other.site_key() != room.site_key()
		):
			return true
	return false


## The levels of [param base] holding a standing or building lift (not coming down) at
## [param origin].
static func shaft_levels(base: BaseState, origin: Vector2i) -> Array[int]:
	var levels: Array[int] = []
	for room: RoomState in base.rooms:
		if (
			room.def_id == StartingBase.LIFT_DEF
			and room.origin == origin
			and not room.is_demolishing()
		):
			levels.append(room.level)
	return levels


## What cancelling the site [param rooms] of [param state] refunds against, in $k: the segment
## price per level for a lift segment, else BaseRules.site_cost_k().
static func site_cost_k(state: GameState, rooms: Array[RoomState]) -> int:
	if not rooms.is_empty() and state.balance != null and is_segment(state.base, rooms[0]):
		return state.balance.lift_segment_cost_k * rooms.size()
	return BaseRules.site_cost_k(state.room_defs, rooms)


## Extends every lift shaft of [param state]'s base into the just-dug [param level]. A shaft
## still building joins the level to its own site for free, as in M2; a finished shaft starts
## a paid segment site, or is refused when funds are short.
static func extend(state: GameState, level: int) -> void:
	var seen: Array[Vector2i] = []
	for room: RoomState in state.base.rooms.duplicate():
		if room.def_id != StartingBase.LIFT_DEF or room.is_demolishing():
			continue
		if room.origin in seen:
			continue
		seen.append(room.origin)
		var building: RoomState = _building_part(state.base, room.origin)
		if building != null:
			var copy: RoomState = state.base.add_room(room.def_id, level, room.origin)
			copy.site = building.site_key()
			copy.build_ticks_left = building.build_ticks_left
			continue
		_start_segment(state, level, room.origin)


## Starts a paid lift segment at [param origin] on [param level], or posts the refusal.
static func _start_segment(state: GameState, level: int, origin: Vector2i) -> void:
	if state.balance == null:
		return
	var cost_k: int = state.balance.lift_segment_cost_k
	if not state.budget.spend_error(cost_k).is_empty():
		state.events.post(&"lift_segment_refused", [level, cost_k])
		return
	state.budget.spend(cost_k)
	var segment: RoomState = state.base.add_room(StartingBase.LIFT_DEF, level, origin)
	segment.site = segment.id
	segment.build_ticks_left = maxi(1, state.balance.lift_segment_ticks)
	state.events.post(&"room_build_started", [segment.id])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## A lift room at [param origin] of [param base] still building, or null.
static func _building_part(base: BaseState, origin: Vector2i) -> RoomState:
	for room: RoomState in base.rooms:
		if room.def_id == StartingBase.LIFT_DEF and room.origin == origin and not room.is_built():
			return room
	return null
