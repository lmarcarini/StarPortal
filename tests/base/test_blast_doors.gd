## Blast doors (M4c-04): built on corridor cells for $50k in 2 hours, never beside the Gate
## Room; sealed and opened while paused; removal refunds as rooms do; a sealed door stops
## paths; demolishing the corridor removes the door; doors survive save and load.
## Bible: docs/content/m4c-incursions.md section 4
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = GameState.new_game(5, Registry.balance())
	var built: Result = GameSetup.build_new(_state, GameDefs.from_registry(Registry))
	_simulation = built.value


## A built corridor cell of the starting base that is not beside the Gate Room.
func _corridor_cell() -> Vector3i:
	for room: RoomState in _state.base.rooms:
		if room.def_id != StartingBase.CORRIDOR_DEF or not room.is_built():
			continue
		if DoorRules.can_build(_state, room.level, room.origin).is_ok:
			return Vector3i(room.origin.x, room.origin.y, room.level)
	return Vector3i(-1, -1, -1)


func _submit(command: Command) -> CommandResult:
	var result: CommandResult = _simulation.submit(command)
	_simulation.advance_tick()
	return result


func test_build_seal_open_and_remove() -> void:
	var at: Vector3i = _corridor_cell()
	assert_int(at.x).is_greater_equal(0)
	var cell := Vector2i(at.x, at.y)
	var funds: int = _state.budget.funds_k
	assert_bool(_submit(BuildDoorCommand.create(at.z, cell)).is_ok).is_true()
	assert_int(_state.budget.funds_k).is_equal(funds - 50)
	var door: DoorState = DoorRules.find(_state.base, at.z, cell)
	assert_bool(door.is_built()).is_false()
	(
		assert_str(
			String(_submit(SetDoorCommand.create(at.z, cell, DoorState.Mode.SEALED)).error_code)
		)
		. is_equal("not_built")
	)
	assert_str(String(BuildDoorCommand.create(at.z, cell).validate(_state).error_code)).is_equal(
		"door_exists"
	)
	for index: int in 130:
		_simulation.advance_tick()
	assert_bool(door.is_built()).is_true()
	var paused := SetDoorCommand.create(at.z, cell, DoorState.Mode.SEALED)
	assert_bool(paused.validate(_state).is_ok).is_true()
	paused.apply(_state)
	assert_int(door.mode).is_equal(DoorState.Mode.SEALED)
	assert_dict(DoorState.from_dict(door.to_dict()).to_dict()).is_equal(door.to_dict())
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_int(GameState.from_dict(data).base.doors[0].mode).is_equal(DoorState.Mode.SEALED)
	var before: int = _state.budget.funds_k
	assert_bool(_submit(RemoveDoorCommand.create(at.z, cell)).is_ok).is_true()
	assert_int(_state.budget.funds_k).is_equal(before)
	assert_object(DoorRules.find(_state.base, at.z, cell)).is_null()


func test_cancelling_an_unbuilt_door_refunds_75_percent() -> void:
	var at: Vector3i = _corridor_cell()
	var cell := Vector2i(at.x, at.y)
	var funds: int = _state.budget.funds_k
	_submit(BuildDoorCommand.create(at.z, cell))
	_submit(RemoveDoorCommand.create(at.z, cell))
	assert_int(_state.budget.funds_k).is_equal(funds - 50 + 37)


func test_not_on_rooms_or_beside_the_gate_room() -> void:
	for room: RoomState in _state.base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			var refusal: CommandResult = DoorRules.can_build(_state, room.level, room.origin)
			assert_str(String(refusal.error_code)).is_equal("not_corridor")
	var found_doorway: bool = false
	for room: RoomState in _state.base.rooms:
		if room.def_id == StartingBase.CORRIDOR_DEF:
			var result: CommandResult = DoorRules.can_build(_state, room.level, room.origin)
			found_doorway = found_doorway or result.error_code == &"gate_doorway"
	assert_bool(found_doorway).is_true()


func test_demolishing_the_corridor_removes_the_door() -> void:
	var at: Vector3i = _corridor_cell()
	var door := DoorState.new()
	door.cell = Vector2i(at.x, at.y)
	door.level = at.z
	_state.base.doors.append(door)
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(_state.base, _state.room_defs)
	_state.base.remove_room(cells[at].id)
	DoorRules.drop_orphans(_state)
	assert_array(_state.base.doors).is_empty()
