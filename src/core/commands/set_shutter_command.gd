class_name SetShutterCommand
extends Command
## Closes or opens the Shutter (M4c-10). Posts shutter_changed.
## Bible: docs/content/m4c-incursions.md section 6

## The command's stable type id.
const TYPE: StringName = &"set_shutter"

## True to close it.
var closed: bool = true


## A command closing ([param close] true) or opening the Shutter.
static func create(close: bool) -> SetShutterCommand:
	var command := SetShutterCommand.new()
	command.closed = close
	return command


## Rebuilds the command from {"type", "closed"}.
static func from_dict(data: Dictionary) -> Result:
	if not data.get("closed") is bool:
		return Result.fail(&"malformed_command", "%s needs closed" % TYPE)
	var close: bool = data["closed"]
	return Result.ok(create(close))


## Returns &"set_shutter".
func get_type() -> StringName:
	return TYPE


## Rejects without a built Shutter (&"not_installed") and closing over an open wormhole
## (&"wormhole_open").
func validate(state: GameState) -> CommandResult:
	if not ShutterRules.is_installed(state):
		return CommandResult.fail(&"not_installed")
	if closed and state.gate.mode == GateState.RingMode.LOCKED:
		return CommandResult.fail(&"wormhole_open")
	return CommandResult.ok()


## Sets it.
func apply(state: GameState) -> void:
	state.gate.shutter = GateState.Shutter.CLOSED if closed else GateState.Shutter.OPEN
	state.events.post(&"shutter_changed", [closed])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "closed": closed}
