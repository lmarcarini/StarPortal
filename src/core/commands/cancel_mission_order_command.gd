class_name CancelMissionOrderCommand
extends Command
## Cancels the running mission order and leaves the gate safe: a dial in progress resolves as
## it will, and a wormhole the order opened is closed unless the team already went through.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)

## The command's stable type id.
const TYPE: StringName = &"cancel_mission_order"

## Rebuilds the command; it has no fields.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(CancelMissionOrderCommand.new())


## Returns &"cancel_mission_order".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_order" when no order runs.
func validate(state: GameState) -> CommandResult:
	if not state.expedition.order.is_active():
		return CommandResult.fail(&"no_order")
	return CommandResult.ok()


## Ends the order as FAILED (cancelled).
func apply(state: GameState) -> void:
	MissionOrderSystem.fail(state, &"cancelled")


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
