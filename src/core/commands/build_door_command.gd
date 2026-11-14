class_name BuildDoorCommand
extends Command
## Builds a blast door on a corridor cell (M4c-04): pays the door's cost and starts it; the
## ConstructionSystem finishes it. Posts door_changed and budget_changed.
## Bible: docs/content/m4c-incursions.md section 4

## The command's stable type id.
const TYPE: StringName = &"build_door"

## Level, from 1.
var level: int = 1
## Corridor cell.
var cell: Vector2i = Vector2i.ZERO


## A command for [param at] on [param on_level].
static func create(on_level: int, at: Vector2i) -> BuildDoorCommand:
	var command := BuildDoorCommand.new()
	command.level = on_level
	command.cell = at
	return command


## Rebuilds the command from {"type", "level", "cell"}.
static func from_dict(data: Dictionary) -> Result:
	if not (RoomState.is_count(data.get("level")) and RoomState.is_cell(data.get("cell"))):
		return Result.fail(&"malformed_command", "%s needs level and cell" % TYPE)
	return Result.ok(create(RoomState.read_count(data["level"]), RoomState.read_cell(data["cell"])))


## Returns &"build_door".
func get_type() -> StringName:
	return TYPE


## DoorRules.can_build(), then &"insufficient_funds".
func validate(state: GameState) -> CommandResult:
	var allowed: CommandResult = DoorRules.can_build(state, level, cell)
	if not allowed.is_ok:
		return allowed
	var funds_error: StringName = state.budget.spend_error(state.balance.door_cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error)
	return CommandResult.ok()


## Pays and starts the door, open.
func apply(state: GameState) -> void:
	var door := DoorState.new()
	door.level = level
	door.cell = cell
	door.build_ticks_left = maxi(1, state.balance.door_build_ticks)
	door.paid_k = state.balance.door_cost_k
	state.budget.spend(door.paid_k)
	state.base.doors.append(door)
	state.events.post(&"door_changed", [level, cell])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "level": level, "cell": [cell.x, cell.y]}
