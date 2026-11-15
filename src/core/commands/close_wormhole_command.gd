class_name CloseWormholeCommand
extends Command
## The player closes the open wormhole. Posts wormhole_closed(&"player") when applied.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"close_wormhole"
## Close reason reported for this command.
const REASON_PLAYER: StringName = &"player"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(CloseWormholeCommand.new())


## Returns &"close_wormhole".
func get_type() -> StringName:
	return TYPE


## Rejects a Ring with no open wormhole (&"not_locked"), and while a conversation runs over
## it (&"conversation_running"; docs/content/dialogue-screen.md section 2).
func validate(state: GameState) -> CommandResult:
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"not_locked")
	var active: ActiveConversation = state.conversations.active
	if active != null and ConversationRules.WORMHOLE_CHANNELS.has(active.channel):
		return CommandResult.fail(&"conversation_running")
	return CommandResult.ok()


## Closes the wormhole and posts wormhole_closed(&"player").
func apply(state: GameState) -> void:
	RingControl.close(state.gate)
	state.events.post(&"wormhole_closed", [REASON_PLAYER])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
