class_name ContentCheckRooms
extends RefCounted
## Content checks for the room definitions: the always-on rule (m2-base.md section 3), a
## size of at least one cell that fits a level's
## grid, no negative cost, build time or power draw, power in whole 5 MW blocks, and no id
## used twice. Pure; returns one
## line per problem.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Every draw, output and charge rate is a multiple of this, in MW.
const BLOCK_MW: float = 5.0


## Returns the problems of [param rooms] against a level of [param grid_size] cells (the size
## must fit either way the room may stand; Vector2i.ZERO means the BalanceConfig default), and
## the always-on rule (always_on_errors()).
static func check(rooms: Array[RoomDef], grid_size: Vector2i = Vector2i.ZERO) -> Array[String]:
	if grid_size == Vector2i.ZERO:
		grid_size = BalanceConfig.new().base_grid_size
	var errors: Array[String] = []
	errors.append_array(always_on_errors(rooms))
	var seen: Dictionary[StringName, bool] = {}
	for room: RoomDef in rooms:
		if seen.has(room.id):
			errors.append("room %s: duplicate id" % room.id)
		seen[room.id] = true
		errors.append_array(_size_errors(room, grid_size))
		if room.build_cost_k < 0:
			errors.append("room %s: build_cost_k %d is negative" % [room.id, room.build_cost_k])
		if room.build_ticks < 0:
			errors.append("room %s: build_ticks %d is negative" % [room.id, room.build_ticks])
		for field: StringName in [&"power_draw_mw", &"power_output_mw", &"max_charge_rate_mw"]:
			var value: float = room.get(field)
			if not (is_finite(value) and value >= 0.0):
				errors.append("room %s: %s is not finite and at least 0" % [room.id, field])
		errors.append_array(block_errors(room))
		if room.upkeep_k < 0:
			errors.append("room %s: upkeep_k %d is negative" % [room.id, room.upkeep_k])
	return errors


## Power comes in whole blocks (m25-lean-start.md section 6): returns a problem for each of
## [param room]'s draw, output and highest charge rate that is not a multiple of
## [constant BLOCK_MW].
static func block_errors(room: RoomDef) -> Array[String]:
	var errors: Array[String] = []
	for field: StringName in [&"power_draw_mw", &"power_output_mw", &"max_charge_rate_mw"]:
		var value: float = room.get(field)
		if is_finite(value) and fmod(value, BLOCK_MW) != 0.0:
			errors.append(
				"room %s: %s %s is not a multiple of %s MW" % [room.id, field, value, BLOCK_MW]
			)
	return errors


## Returns the always-on rule's problem, if any: the always-on rooms' total draw must be no
## higher than the smallest plant's output (m2-base.md section 3); a draw with no plant at all
## is rejected too.
static func always_on_errors(rooms: Array[RoomDef]) -> Array[String]:
	var errors: Array[String] = []
	var draw: float = 0.0
	var smallest: float = INF
	for room: RoomDef in rooms:
		if room.always_on:
			draw += room.power_draw_mw
		if room.power_output_mw > 0.0:
			smallest = minf(smallest, room.power_output_mw)
	if draw > 0.0 and smallest == INF:
		errors.append("rooms: always-on rooms draw %s MW but no room gives power output" % draw)
	elif draw > smallest:
		errors.append(
			"rooms: always-on draw %s MW is above the smallest plant's %s MW" % [draw, smallest]
		)
	return errors


static func _size_errors(room: RoomDef, grid_size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	var size: Vector2i = room.size_cells
	if size.x < 1 or size.y < 1:
		errors.append("room %s: size_cells %s is below one cell" % [room.id, size])
	elif size.x > grid_size.x or size.y > grid_size.y:
		errors.append("room %s: size_cells %s does not fit a %s level" % [room.id, size, grid_size])
	elif room.rotatable and (size.y > grid_size.x or size.x > grid_size.y):
		errors.append(
			"room %s: size_cells %s does not fit a %s level turned" % [room.id, size, grid_size]
		)
	return errors
