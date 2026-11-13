class_name AnswerCallCommand
extends Command
## The player answers the oldest waiting phone call: it leaves the pending list and its
## conversation starts on channel &"phone" (no wormhole).
## Bible: docs/content/m4-core-systems.md section 3 (Phone)

## The command's stable type id.
const TYPE: StringName = &"answer_call"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(AnswerCallCommand.new())


## Returns &"answer_call".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_call" or &"conversation_running".
func validate(state: GameState) -> CommandResult:
	if ContactRules.next_pending(state, &"phone") < 0:
		return CommandResult.fail(&"no_call")
	if state.conversations.active != null:
		return CommandResult.fail(&"conversation_running")
	return CommandResult.ok()


## Starts the call's conversation.
func apply(state: GameState) -> void:
	var index: int = ContactRules.next_pending(state, &"phone")
	var contact: PendingContact = state.factions.pending[index]
	state.factions.pending.remove_at(index)
	ConversationRules.start(state, contact.conversation, &"phone", &"")


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
