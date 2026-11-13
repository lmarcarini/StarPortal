class_name ChooseOptionCommand
extends Command
## The player picks answer [member index] at the running conversation's Choice node.
## Bible: docs/content/m4-core-systems.md section 3

## The command's stable type id.
const TYPE: StringName = &"choose_option"

## Index of the answer in the Choice node's list (not the shown order).
var index: int = 0


func _init(choice_index: int = 0) -> void:
	index = choice_index


## Rebuilds the command from {"type", "index"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_int(data.get("index")):
		return Result.fail(&"malformed_command", "choose_option needs a whole index")
	return Result.ok(ChooseOptionCommand.new(SaveFields.read_int(data["index"])))


## Returns &"choose_option".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_conversation", &"not_at_choice", &"no_such_choice" or &"choice_locked".
func validate(state: GameState) -> CommandResult:
	var error: StringName = ConversationRules.choose_error(state, index)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Picks the answer.
func apply(state: GameState) -> void:
	ConversationRules.choose(state, index)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "index": index}
