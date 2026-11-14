class_name OperateGateCommand
extends Command
## Brings the gate operations panel up on the open wormhole (docs/content/event-time.md section
## 3): sets [member GateState.operating], which slows the clock (gate_ops) until Stand by,
## leaving the Gate Room or the wormhole closing.
## Bible: docs/content/event-time.md section 3

## The command's stable type id.
const TYPE: StringName = &"operate_gate"


## Rebuilds the command from {"type"}.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(OperateGateCommand.new())


## Returns &"operate_gate".
func get_type() -> StringName:
	return TYPE


## Rejects with no open wormhole (&"no_wormhole"), on an answered incoming one, which the
## conversation slows instead (&"incoming_lock"), or when already operating (&"operating").
func validate(state: GameState) -> CommandResult:
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"no_wormhole")
	if state.gate.is_incoming_lock():
		return CommandResult.fail(&"incoming_lock")
	if state.gate.operating:
		return CommandResult.fail(&"operating")
	return CommandResult.ok()


## Sets operating and adds the gate_ops slow.
func apply(state: GameState) -> void:
	state.gate.operating = true
	TimeControl.add_slow(state.clock, &"gate_ops")


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
