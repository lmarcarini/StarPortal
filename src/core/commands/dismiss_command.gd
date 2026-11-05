class_name DismissCommand
extends Command
## The player dismisses someone from the roster (docs/content/m26-staff-and-money.md
## section 2): immediate, no refund of the fee, no severance. Their room slot and bed free at
## once; a person still arriving is cancelled the same way. Posts
## staff_changed(&"dismissed", def id of the room left or &"", 1).
## Bible: docs/content/m26-staff-and-money.md section 2

## The command's stable type id.
const TYPE: StringName = &"dismiss"

## Id of the person to dismiss.
var person_id: StringName = &""


## Returns a command that dismisses [param person].
static func create(person: StringName) -> DismissCommand:
	var command := DismissCommand.new()
	command.person_id = person
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "person_id" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var person: Variant = data.get("person_id")
	if not person is String:
		return Result.fail(&"malformed_command", "%s needs a string person_id" % TYPE)
	return Result.ok(create(StringName(str(person))))


## Returns &"dismiss".
func get_type() -> StringName:
	return TYPE


## Refuses an unknown person (&"unknown_person").
func validate(state: GameState) -> CommandResult:
	var error: StringName = RecruitmentRules.dismiss_error(state, person_id)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Takes the person off the roster.
func apply(state: GameState) -> void:
	var person: PersonState = state.staff.find_person(person_id)
	var room: RoomState = state.base.find_room(person.room_id) if person.is_assigned() else null
	var def_id: StringName = &"" if room == null else room.def_id
	state.staff.remove_person(person_id)
	state.events.post(&"staff_changed", [RecruitmentRules.DISMISSED, def_id, 1])


## Returns JSON-safe data: the type and "person_id".
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "person_id": String(person_id)}
