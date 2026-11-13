class_name RetrieveArtefactCommand
extends Command
## Bring artefact [member uid] waiting at the gate into holding (ArtefactRules).
## Bible: docs/content/m4-core-systems.md section 5

## The command's stable type id.
const TYPE: StringName = &"retrieve_artefact"

## Uid of the artefact.
var uid: int = 0


func _init(artefact_uid: int = 0) -> void:
	uid = artefact_uid


## Rebuilds the command from its to_dict() data.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_tick(data.get("uid")):
		return Result.fail(&"malformed_command", "retrieve_artefact needs uid")
	return Result.ok(RetrieveArtefactCommand.new(SaveFields.read_int(data["uid"])))


## Returns &"retrieve_artefact".
func get_type() -> StringName:
	return TYPE


## Rejects with ArtefactRules' code.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ArtefactRules.retrieve_error(state, uid)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Moves the artefact.
func apply(state: GameState) -> void:
	ArtefactRules.move(state, uid, ArtefactRecord.IN_HOLDING)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "uid": uid}
