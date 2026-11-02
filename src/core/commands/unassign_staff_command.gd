class_name UnassignStaffCommand
extends Command
## The player takes a person out of their room; they become Unassigned
## (docs/content/m26-staff-and-money.md section 6). Instant and free. Posts
## staff_changed(&"unassigned", def id of the room left, 1) when they had a room.
## Bible: docs/content/m26-staff-and-money.md sections 3 and 6

## The command's stable type id.
const TYPE: StringName = &"unassign_staff"

## Id of the person to unassign.
var person_id: StringName = &""


## Returns a command that unassigns [param person].
static func create(person: StringName) -> UnassignStaffCommand:
	var command := UnassignStaffCommand.new()
	command.person_id = person
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "person_id" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var person: Variant = data.get("person_id")
	if not person is String:
		return Result.fail(&"malformed_command", "%s needs a string person_id" % TYPE)
	return Result.ok(create(StringName(str(person))))


## Returns &"unassign_staff".
func get_type() -> StringName:
	return TYPE


## Refuses an unknown person (&"unknown_person"). Someone already Unassigned is accepted.
func validate(state: GameState) -> CommandResult:
	var error: StringName = StaffRules.unassign_error(state, person_id)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Makes the person Unassigned.
func apply(state: GameState) -> void:
	StaffChanges.unassign(state, state.staff.find_person(person_id))


## Returns JSON-safe data: type and person_id.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "person_id": String(person_id)}
