class_name UnhouseArtefactCommand
extends Command
## Take housed artefact [member uid] back to Gate Room holding (ArtefactRules).
## Bible: docs/content/m4-core-systems.md section 5

## The command's stable type id.
const TYPE: StringName = &"unhouse_artefact"

## Uid of the artefact.
var uid: int = 0


func _init(artefact_uid: int = 0) -> void:
	uid = artefact_uid


## Rebuilds the command from its to_dict() data.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_tick(data.get("uid")):
		return Result.fail(&"malformed_command", "unhouse_artefact needs uid")
	return Result.ok(UnhouseArtefactCommand.new(SaveFields.read_int(data["uid"])))


## Returns &"unhouse_artefact".
func get_type() -> StringName:
	return TYPE


## Rejects with ArtefactRules' code.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ArtefactRules.unhouse_error(state, uid)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Moves the artefact.
func apply(state: GameState) -> void:
	ArtefactRules.move(state, uid, ArtefactRecord.IN_HOLDING)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "uid": uid}
