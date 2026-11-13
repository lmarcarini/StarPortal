class_name HailCommand
extends Command
## The player hails the world the Ring is locked to: the best wormhole conversation of the
## world's faction starts (meeting the faction the first time), or the Log reads "No answer.".
## Bible: docs/content/m4-core-systems.md section 3 (Hail)

## The command's stable type id.
const TYPE: StringName = &"hail"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(HailCommand.new())


## Returns &"hail".
func get_type() -> StringName:
	return TYPE


## Rejects with &"cannot_hail" unless GateQueries.can_hail().
func validate(state: GameState) -> CommandResult:
	return CommandResult.ok() if GateQueries.can_hail(state) else CommandResult.fail(&"cannot_hail")


## Starts the best conversation, or posts hail_unanswered.
func apply(state: GameState) -> void:
	var world: StringName = state.gate.connected_world_id
	var faction: StringName = GateQueries.locked_faction(state)
	var conversation: StringName = &""
	if not faction.is_empty():
		conversation = ConversationRules.pick(faction, &"wormhole", world, state)
	if conversation.is_empty():
		state.events.post(&"hail_unanswered", [world])
		return
	FactionRules.meet(state, faction)
	ConversationRules.start(state, conversation, &"wormhole", world)


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
