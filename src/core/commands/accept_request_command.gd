class_name AcceptRequestCommand
extends Command
## The player accepts the offered request [member uid]: OFFERED → ACTIVE.
## Bible: docs/content/m4-core-systems.md section 4

## The command's stable type id.
const TYPE: StringName = &"accept_request"

## Uid of the request instance.
var uid: int = 0


func _init(request_uid: int = 0) -> void:
	uid = request_uid


## Rebuilds the command from {"type", "uid"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_tick(data.get("uid")):
		return Result.fail(&"malformed_command", "accept_request needs a uid")
	return Result.ok(AcceptRequestCommand.new(SaveFields.read_int(data["uid"])))


## Returns &"accept_request".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_such_request" or &"not_offered".
func validate(state: GameState) -> CommandResult:
	var error: StringName = RequestRules.offer_error(state, uid)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## OFFERED → ACTIVE.
func apply(state: GameState) -> void:
	RequestRules.accept(state, uid)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "uid": uid}
