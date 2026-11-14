class_name AssignMode
extends RefCounted
## Placing one person on the plan, by drag or select-then-place: which rooms can take them
## (the assign command's own validation) and placing or unassigning through the existing
## commands. No new commands. Presentation only.
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)

## The person being placed, or &"" when not placing.
var person_id: StringName = &""
## The last refusal's text, "" after a success.
var last_reason: String = ""

var _allowed: Dictionary[StringName, bool] = {}


## Starts placing [param person] over the rooms of [param state].
func start(state: GameState, person: StringName) -> void:
	person_id = person
	last_reason = ""
	_allowed.clear()
	for room: RoomState in state.base.rooms:
		if AssignStaffCommand.create(person, room.id).validate(state).is_ok:
			_allowed[room.id] = true


## True while placing.
func is_active() -> bool:
	return person_id != &""


## True when [param room_id] can take the person.
func allows(room_id: StringName) -> bool:
	return _allowed.has(room_id)


## Every room that can take the person.
func allowed_rooms() -> Array[StringName]:
	return _allowed.keys()


## Assigns the person to [param room_id] through [param simulation]; ends placing on success
## and keeps the refusal's text otherwise. Returns true on success.
func place(simulation: Simulation, room_id: StringName) -> bool:
	var result: CommandResult = simulation.submit(AssignStaffCommand.create(person_id, room_id))
	return _finish(result)


## Unassigns the person (a drop on the tray). Returns true on success.
func unassign(simulation: Simulation) -> bool:
	var result: CommandResult = simulation.submit(UnassignStaffCommand.create(person_id))
	return _finish(result)


## Stops placing.
func cancel() -> void:
	person_id = &""
	_allowed.clear()


func _finish(result: CommandResult) -> bool:
	if result.is_ok:
		last_reason = ""
		cancel()
		return true
	last_reason = PersonnelText.refusal(result.error_code)
	return false
