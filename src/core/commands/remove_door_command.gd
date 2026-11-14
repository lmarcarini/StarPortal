class_name RemoveDoorCommand
extends Command
## Removes a blast door (M4c-04): an unbuilt one refunds 75%, a built one nothing, as rooms.
## Posts door_changed and budget_changed.
## Bible: docs/content/m4c-incursions.md section 4

## The command's stable type id.
const TYPE: StringName = &"remove_door"

## Level, from 1.
var level: int = 1
## Corridor cell.
var cell: Vector2i = Vector2i.ZERO


## A command for [param at] on [param on_level].
static func create(on_level: int, at: Vector2i) -> RemoveDoorCommand:
	var command := RemoveDoorCommand.new()
	command.level = on_level
	command.cell = at
	return command


## Rebuilds the command from {"type", "level", "cell"}.
static func from_dict(data: Dictionary) -> Result:
	if not (RoomState.is_count(data.get("level")) and RoomState.is_cell(data.get("cell"))):
		return Result.fail(&"malformed_command", "%s needs level and cell" % TYPE)
	return Result.ok(create(RoomState.read_count(data["level"]), RoomState.read_cell(data["cell"])))


## Returns &"remove_door".
func get_type() -> StringName:
	return TYPE


## Rejects when there is no door there (&"no_door").
func validate(state: GameState) -> CommandResult:
	if DoorRules.find(state.base, level, cell) == null:
		return CommandResult.fail(&"no_door")
	return CommandResult.ok()


## Removes the door and refunds.
func apply(state: GameState) -> void:
	var door: DoorState = DoorRules.find(state.base, level, cell)
	state.base.doors.erase(door)
	state.events.post(&"door_changed", [level, cell])
	var refund: int = DoorRules.refund_k(door)
	if refund > 0:
		state.budget.credit(refund)
		state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "level": level, "cell": [cell.x, cell.y]}
