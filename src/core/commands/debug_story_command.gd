class_name DebugStoryCommand
extends Command
## Debug builds only: sets a faction's standing, meets a faction, sets a flag, offers a request
## or queues a conversation as a pending contact, so story states can be tested quickly. Each
## writes a Log line marked "(debug)". Refused in release builds.
## Bible: docs/content/m4-core-systems.md section 8

## The command's stable type id.
const TYPE: StringName = &"debug_story"
## The actions.
const ACTIONS: Array[StringName] = [
	&"standing", &"meet", &"flag", &"offer", &"contact", &"incursion"
]

## One of ACTIONS.
var action: StringName = &""
## Faction, flag, request or conversation id.
var id: StringName = &""
## Standing value or flag value (an int when it reads as one, "true"/"false" as a bool).
var value: String = ""


## A command doing [param what] to [param target] with [param with_value].
static func create(
	what: StringName, target: StringName, with_value: String = ""
) -> DebugStoryCommand:
	var command := DebugStoryCommand.new()
	command.action = what
	command.id = target
	command.value = with_value
	return command


## Rebuilds the command from {"type", "action", "id", "value"}.
static func from_dict(data: Dictionary) -> Result:
	for key: String in ["action", "id", "value"]:
		if not data.get(key) is String:
			return Result.fail(&"malformed_command", "debug_story needs " + key)
	return Result.ok(
		create(StringName(str(data["action"])), StringName(str(data["id"])), str(data["value"]))
	)


## Returns &"debug_story".
func get_type() -> StringName:
	return TYPE


## Rejects outside debug builds (&"debug_only"), an unknown action (&"bad_action") or an id
## the action cannot use (&"unknown_id").
func validate(state: GameState) -> CommandResult:
	if not OS.is_debug_build():
		return CommandResult.fail(&"debug_only")
	if not ACTIONS.has(action):
		return CommandResult.fail(&"bad_action")
	var known: bool = true
	match action:
		&"standing", &"meet":
			known = state.faction_defs.has(id)
		&"flag":
			known = not id.is_empty()
		&"offer":
			known = state.request_defs.has(id)
		&"contact":
			known = state.conversation_defs.has(id)
		&"incursion":
			known = state.incursion_defs.has(id)
	return CommandResult.ok() if known else CommandResult.fail(&"unknown_id")


## Does the action and posts debug_story.
func apply(state: GameState) -> void:
	match action:
		&"standing":
			var target: int = value.to_int()
			FactionRules.change(
				state, id, target - FactionRules.standing(state, id), &"DEBUG_CAUSE"
			)
		&"meet":
			FactionRules.meet(state, id)
		&"flag":
			StoryRules.apply(state, _flag_effect(), &"debug")
		&"offer":
			StoryRulesItems.offer_request(state, id)
		&"contact":
			var conversation: ConversationDef = state.conversation_defs[id]
			var faction: FactionDef = state.faction_defs.get(conversation.faction)
			if faction != null:
				ContactRules.queue(state, faction, id)
		&"incursion":
			IncursionRules.start(state, id)
	state.events.post(&"debug_story", [action, id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "action": String(action), "id": String(id), "value": value}


func _flag_effect() -> SetFlagEffect:
	var effect := SetFlagEffect.new()
	effect.flag = id
	if value == "true" or value == "false":
		effect.value = value == "true"
	elif value.is_valid_int():
		effect.value = value.to_int()
	else:
		effect.value = value
	return effect
