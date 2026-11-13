class_name HouseArtefactCommand
extends Command
## House artefact [member uid] in room uid [member room_uid] (ArtefactRules).
## Bible: docs/content/m4-core-systems.md section 5

## The command's stable type id.
const TYPE: StringName = &"house_artefact"

## Uid of the artefact.
var uid: int = 0
## Uid of the room (room id "room_<n>" → n).
var room_uid: int = -1


func _init(artefact_uid: int = 0, target_room_uid: int = -1) -> void:
	uid = artefact_uid
	room_uid = target_room_uid


## Rebuilds the command from its to_dict() data.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_tick(data.get("uid")) or not SaveFields.is_tick(data.get("room_uid")):
		return Result.fail(&"malformed_command", "house_artefact needs uid and room_uid")
	return Result.ok(
		HouseArtefactCommand.new(
			SaveFields.read_int(data["uid"]), SaveFields.read_int(data["room_uid"])
		)
	)


## Returns &"house_artefact".
func get_type() -> StringName:
	return TYPE


## Rejects with ArtefactRules' code.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ArtefactRules.house_error(state, uid, room_uid)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Moves the artefact.
func apply(state: GameState) -> void:
	ArtefactRules.move(state, uid, room_uid)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "uid": uid, "room_uid": room_uid}
