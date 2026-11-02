class_name PaintCorridorCommand
extends Command
## The player drags a corridor run across free cells of one level and holds to build: pays the
## corridor's cost per cell (at most the level's cell count) and starts one site. The run's
## cells finish one by one, the def's build time apart, so the whole run takes that time per
## cell. Posts room_build_started(site id) and budget_changed when applied.
## Bible: docs/content/m2-base.md sections 1 and 4

## The command's stable type id.
const TYPE: StringName = &"paint_corridor"

## Level number (1 the top).
var level: int = 1
## The run's cells, in painting order; each joins an earlier one by an edge.
var cells: Array[Vector2i] = []


## Returns a command that paints [param run] on [param on_level].
static func create(on_level: int, run: Array[Vector2i]) -> PaintCorridorCommand:
	var command := PaintCorridorCommand.new()
	command.level = on_level
	command.cells = run.duplicate()
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "level" is not a whole number or "cells" is not an array of cells.
static func from_dict(data: Dictionary) -> Result:
	var cell_data: Variant = data.get("cells")
	if not (RoomState.is_count(data.get("level")) and cell_data is Array):
		return Result.fail(&"malformed_command", "%s needs level and cells" % TYPE)
	var entries: Array = cell_data
	var run: Array[Vector2i] = []
	for entry: Variant in entries:
		if not RoomState.is_cell(entry):
			return Result.fail(&"malformed_command", "%s cell is not two whole numbers" % TYPE)
		run.append(RoomState.read_cell(entry))
	return Result.ok(create(RoomState.read_count(data["level"]), run))


## Returns &"paint_corridor".
func get_type() -> StringName:
	return TYPE


## Rejects a missing or locked corridor (BaseRules.can_build_room(): &"unknown_room" and the
## research reasons), an empty, repeating or broken run, or one longer than the level has
## cells (&"invalid_run"), a cell breaking a
## placement rule (&"no_such_level", &"level_not_dug", &"outside_level", &"overlap"), a run
## touching no room, corridor, lift or stairs (&"not_connected") and too little money
## (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	var unlocked: CommandResult = BaseRules.can_build_room(state, StartingBase.CORRIDOR_DEF)
	if not unlocked.is_ok:
		return unlocked
	var def: RoomDef = state.room_defs[StartingBase.CORRIDOR_DEF]
	if not _is_run(state.base.grid_size.x * state.base.grid_size.y):
		return CommandResult.fail(&"invalid_run")
	var connected: bool = false
	for cell: Vector2i in cells:
		var room := RoomState.create(&"", def.id, level, cell)
		var error: StringName = BaseRules.placement_error(state.base, state.room_defs, room)
		if not error.is_empty():
			return CommandResult.fail(error, "cell %s" % cell)
		connected = (
			connected or not BaseRules.neighbours(state.base, state.room_defs, room).is_empty()
		)
	if not connected:
		return CommandResult.fail(&"not_connected")
	var cost_k: int = def.build_cost_k * cells.size()
	var funds_error: StringName = state.budget.spend_error(cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error, "needs %dk" % cost_k)
	return CommandResult.ok()


## Pays the cost and adds one unbuilt corridor per cell, all in one site.
func apply(state: GameState) -> void:
	var def: RoomDef = state.room_defs[StartingBase.CORRIDOR_DEF]
	state.budget.spend(def.build_cost_k * cells.size())
	var site_id: StringName = &""
	for index: int in cells.size():
		var room: RoomState = state.base.add_room(def.id, level, cells[index])
		room.build_ticks_left = maxi(1, def.build_ticks) * (index + 1)
		if site_id.is_empty():
			site_id = room.id
		room.site = site_id
	state.events.post(&"room_build_started", [site_id])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data: type, level and cells.
func to_dict() -> Dictionary:
	var cell_data: Array = []
	for cell: Vector2i in cells:
		cell_data.append([cell.x, cell.y])
	return {"type": String(TYPE), "level": level, "cells": cell_data}


## True when the run has 1 to [param max_cells] distinct cells, each after the first sharing an
## edge with an earlier one.
func _is_run(max_cells: int) -> bool:
	if cells.is_empty() or cells.size() > max_cells:
		return false
	var seen: Dictionary[Vector2i, bool] = {}
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		if seen.has(cell):
			return false
		if index > 0 and not _joins(seen, cell):
			return false
		seen[cell] = true
	return true


static func _joins(seen: Dictionary[Vector2i, bool], cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if seen.has(cell + step):
			return true
	return false
