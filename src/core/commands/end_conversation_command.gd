class_name EndConversationCommand
extends Command
## The player hangs up a phone conversation: the link ends as cut off (End effects not
## applied) and the player closes the screen with AdvanceConversationCommand. Wormhole
## conversations end only when the wormhole closes.
## Bible: docs/content/m4-core-systems.md section 3

## The command's stable type id.
const TYPE: StringName = &"end_conversation"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(EndConversationCommand.new())


## Returns &"end_conversation".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_conversation" or &"not_phone".
func validate(state: GameState) -> CommandResult:
	if state.conversations.active == null:
		return CommandResult.fail(&"no_conversation")
	if state.conversations.active.channel != &"phone":
		return CommandResult.fail(&"not_phone")
	if state.conversations.active.phase == ActiveConversation.Phase.ENDED:
		return CommandResult.fail(&"already_ended")
	return CommandResult.ok()


## Ends the call as cut off (its End was not reached).
func apply(state: GameState) -> void:
	ConversationRules.end_link(state, true)


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
