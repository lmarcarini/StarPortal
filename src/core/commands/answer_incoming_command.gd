class_name AnswerIncomingCommand
extends Command
## The player answers the waiting incoming wormhole (IncomingRules.answer).
## Bible: docs/content/m4-core-systems.md section 3 (Incoming wormhole)

## The command's stable type id.
const TYPE: StringName = &"answer_incoming"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(AnswerIncomingCommand.new())


## Returns &"answer_incoming".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_incoming" when no incoming wormhole waits.
func validate(state: GameState) -> CommandResult:
	return CommandResult.ok() if state.gate.has_incoming() else CommandResult.fail(&"no_incoming")


## Answers the incoming wormhole (IncomingRules.answer).
func apply(state: GameState) -> void:
	IncomingRules.answer(state)


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
