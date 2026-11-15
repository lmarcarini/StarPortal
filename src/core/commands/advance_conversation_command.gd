class_name AdvanceConversationCommand
extends Command
## The player moves the running conversation on: from the opening to the first node, from a
## line to the next node, and closes it once it has ended. Applies while the clock is held.
## Bible: docs/content/dialogue-screen.md sections 2 and 7

## The command's stable type id.
const TYPE: StringName = &"advance_conversation"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(AdvanceConversationCommand.new())


## Returns &"advance_conversation".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_conversation" or &"needs_choice".
func validate(state: GameState) -> CommandResult:
	var error: StringName = ConversationRules.advance_error(state)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Moves the conversation on.
func apply(state: GameState) -> void:
	ConversationRules.advance(state)


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
