class_name ContentCheckRooms
extends RefCounted
## Content checks for the room definitions: a size of at least one cell that fits a level's
## grid, no negative cost, build time or power draw, and no id used twice. Pure; returns one
## line per problem.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model


## Returns the problems of [param rooms] against a level of [param grid_size] cells (the size
## must fit either way the room may stand).
static func check(
	rooms: Array[RoomDef], grid_size: Vector2i = BaseState.DEFAULT_GRID_SIZE
) -> Array[String]:
	var errors: Array[String] = []
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
		if room.upkeep_k_per_month < 0:
			errors.append(
				"room %s: upkeep_k_per_month %d is negative" % [room.id, room.upkeep_k_per_month]
			)
		if not (is_finite(room.power_draw_mw) and room.power_draw_mw >= 0.0):
			errors.append("room %s: power_draw_mw is not finite and at least 0" % room.id)
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
