class_name AssignStaffCommand
extends Command
## The player puts a person in a room with a free slot of their role
## (docs/content/m26-staff-and-money.md sections 3 and 6). Moving someone is just assigning
## them elsewhere. Instant and free. Posts staff_changed(&"assigned", room def id, 1).
## Bible: docs/content/m26-staff-and-money.md sections 3 and 6

## The command's stable type id.
const TYPE: StringName = &"assign_staff"

## Id of the person to assign.
var person_id: StringName = &""
## Id of the room to put them in.
var room_id: StringName = &""


## Returns a command that assigns [param person] to room [param room].
static func create(person: StringName, room: StringName) -> AssignStaffCommand:
	var command := AssignStaffCommand.new()
	command.person_id = person
	command.room_id = room
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "person_id" or "room_id" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var person: Variant = data.get("person_id")
	var room: Variant = data.get("room_id")
	if not (person is String and room is String):
		return Result.fail(&"malformed_command", "%s needs person_id and room_id" % TYPE)
	return Result.ok(create(StringName(str(person)), StringName(str(room))))


## Returns &"assign_staff".
func get_type() -> StringName:
	return TYPE


## Refuses with StaffRules.assign_error(): &"unknown_person", &"unknown_room", &"not_on_base",
## &"not_built", &"wrong_role" or &"room_full".
func validate(state: GameState) -> CommandResult:
	var error: StringName = StaffRules.assign_error(state, person_id, room_id)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Puts the person in the room.
func apply(state: GameState) -> void:
	StaffChanges.assign(state, state.staff.find_person(person_id), state.base.find_room(room_id))


## Returns JSON-safe data: type, person_id and room_id.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "person_id": String(person_id), "room_id": String(room_id)}
