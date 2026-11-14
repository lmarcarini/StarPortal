class_name SetDoorCommand
extends Command
## Seals or opens a built blast door (M4c-04), also while paused. Opening clears any breach
## progress. Posts door_changed.
## Bible: docs/content/m4c-incursions.md section 4

## The command's stable type id.
const TYPE: StringName = &"set_door"

## Level, from 1.
var level: int = 1
## Corridor cell.
var cell: Vector2i = Vector2i.ZERO
## OPEN or SEALED.
var mode: DoorState.Mode = DoorState.Mode.OPEN


## A command setting the door at [param at] on [param on_level] to [param to_mode].
static func create(on_level: int, at: Vector2i, to_mode: DoorState.Mode) -> SetDoorCommand:
	var command := SetDoorCommand.new()
	command.level = on_level
	command.cell = at
	command.mode = to_mode
	return command


## Rebuilds the command from {"type", "level", "cell", "mode"}.
static func from_dict(data: Dictionary) -> Result:
	if not (RoomState.is_count(data.get("level")) and RoomState.is_cell(data.get("cell"))):
		return Result.fail(&"malformed_command", "%s needs level and cell" % TYPE)
	if not StateNames.is_name(DoorState.MODE_NAMES, data.get("mode")):
		return Result.fail(&"malformed_command", "%s needs mode open or sealed" % TYPE)
	var to_mode: DoorState.Mode = (
		StateNames.read(DoorState.MODE_NAMES, data["mode"]) as DoorState.Mode
	)
	return Result.ok(
		create(RoomState.read_count(data["level"]), RoomState.read_cell(data["cell"]), to_mode)
	)


## Returns &"set_door".
func get_type() -> StringName:
	return TYPE


## Rejects with no door there (&"no_door") or one still being built (&"not_built").
## A breached door is gone, so it reports &"no_door" too.
func validate(state: GameState) -> CommandResult:
	var door: DoorState = DoorRules.find(state.base, level, cell)
	if door == null:
		return CommandResult.fail(&"no_door")
	if not door.is_built():
		return CommandResult.fail(&"not_built")
	return CommandResult.ok()


## Sets the mode.
func apply(state: GameState) -> void:
	var door: DoorState = DoorRules.find(state.base, level, cell)
	door.mode = mode
	if mode == DoorState.Mode.OPEN:
		door.breach_ticks = 0
	state.events.post(&"door_changed", [level, cell])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"level": level,
		"cell": [cell.x, cell.y],
		"mode": StateNames.write(DoorState.MODE_NAMES, mode),
	}
