class_name StandByCommand
extends Command
## Stand by on the open wormhole (docs/content/event-time.md section 3): clears
## [member GateState.operating] and releases gate_ops; the wormhole stays open.
## Bible: docs/content/event-time.md section 3

## The command's stable type id.
const TYPE: StringName = &"stand_by"


## Rebuilds the command from {"type"}.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(StandByCommand.new())


## Returns &"stand_by".
func get_type() -> StringName:
	return TYPE


## Rejects when the gate is not being operated (&"not_operating").
func validate(state: GameState) -> CommandResult:
	if not state.gate.operating:
		return CommandResult.fail(&"not_operating")
	return CommandResult.ok()


## Clears operating and releases gate_ops.
func apply(state: GameState) -> void:
	state.gate.operating = false
	TimeControl.release_slow(state.clock, &"gate_ops")


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
