## The M4c loop on the real content through commands (M4c-17): (a) sabotage beaten at a sealed
## door; (b) theft succeeds and the artefact is lost; (c) assault holds the Control Room, the
## game ends in Overrun and the last save loads; (d) the Shutter stops a wave; (e) Confidence
## 0 for 7 days warns and play goes on; (f) research, install a rack, order and launch a MOTH;
## (g) a sentry gun holds a room (the intruders do not finish the job).
## Bible: docs/content/m4c-incursions.md
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const PowerFixture := preload("res://tests/power/power_fixture.gd")
const SaveServiceScript := preload("res://src/services/save_service.gd")

var _defs: GameDefs
var _state: GameState
var _simulation: Simulation
var _ended: Array[Dictionary] = []
## The cell before the door _seal_on_path_to() sealed, where intruders wait.
var _waiting: Vector3i = Vector3i.ZERO


func before_test() -> void:
	DebugCheatCommand.force_enabled = 1
	_defs = GameDefs.from_registry(Registry)
	_new_game()


func after_test() -> void:
	DebugCheatCommand.force_enabled = -1


func _new_game() -> void:
	_state = GameState.new_game(7, _defs.balance)
	_simulation = GameSetup.build_new(_state, _defs).value
	_simulation.event_posted.connect(_on_event)
	_state.clock.mode = ClockState.Mode.RUNNING
	_state.budget.funds_k += 20000
	_ended.clear()


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"incursion_ended" and not args.is_empty() and args[0] is Dictionary:
		_ended.append(args[0])


func _ticks(count: int) -> void:
	for index: int in count:
		if _state.outcome.has_failed():
			return
		_simulation.advance_tick()


func _submit(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	(
		assert_bool(result.is_ok)
		. override_failure_message("%s refused: %s" % [command.get_type(), result.error_code])
		. is_true()
	)
	_ticks(1)


## Starts the test incursion [param id] and skips its warning.
func _incursion(id: StringName) -> void:
	_submit(DebugCheatCommand.create(&"incursion", id))
	_submit(DebugCheatCommand.create(&"skip_warning"))
	_ticks(2)


## Ticks until the incursion ends, at most [param limit] ticks.
func _until_over(limit: int = 2000) -> void:
	for guard: int in limit:
		if not _state.incursion.is_active() or _state.outcome.has_failed():
			return
		_ticks(1)


## Builds the first Capacitor Bank and fills it.
func _charged_bank() -> void:
	_submit(PowerFixture.build_first_bank(_state))
	for guard: int in 30 * TimeMath.TICKS_PER_DAY:
		if PowerRules.capacity_of(_state, PowerRules.totals(_state)) > 0.0:
			break
		_ticks(1)
	_state.power.stored_mwh = PowerRules.capacity_of(_state, PowerRules.totals(_state))


func _room(def_id: StringName) -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


## Builds a blast door at the first spot on the path from the Ring to [param room] that cuts
## every way there, seals it and returns it.
func _seal_on_path_to(room: RoomState) -> DoorState:
	var from: Vector3i = IncursionRules.gate_cell(_state)
	var to := Vector3i(room.origin.x, room.origin.y, room.level)
	var path: PackedVector3Array = BasePaths.find(_state.base, from, to, _state.room_defs)
	var cell := Vector3i(-1, -1, -1)
	for point: Vector3 in path:
		var at := Vector3i(int(point.x), int(point.y), int(point.z))
		if _blocks(at, from, to):
			cell = at
			break
		_waiting = at
	assert_int(cell.z).is_not_equal(-1)
	_submit(BuildDoorCommand.create(cell.z, Vector2i(cell.x, cell.y)))
	var door: DoorState = DoorRules.find(_state.base, cell.z, Vector2i(cell.x, cell.y))
	for guard: int in 30 * TimeMath.TICKS_PER_DAY:
		if door.is_built():
			break
		_ticks(1)
	_submit(SetDoorCommand.create(cell.z, Vector2i(cell.x, cell.y), DoorState.Mode.SEALED))
	return door


## True when a sealed door may stand at [param at] and would cut every way [param from] to
## [param to].
func _blocks(at: Vector3i, from: Vector3i, to: Vector3i) -> bool:
	if not DoorRules.can_build(_state, at.z, Vector2i(at.x, at.y)).is_ok:
		return false
	var probe := DoorState.new()
	probe.level = at.z
	probe.cell = Vector2i(at.x, at.y)
	probe.mode = DoorState.Mode.SEALED
	_state.base.doors.append(probe)
	var cut: bool = BasePaths.find(_state.base, from, to, _state.room_defs).is_empty()
	_state.base.doors.erase(probe)
	return cut


## Builds a Security Post, fills it with [param count] soldiers and returns its squad.
func _squad(count: int) -> SquadState:
	var post: RoomState = null
	for x: int in range(2, _state.base.grid_size.x - 2):
		var command := PlaceRoomCommand.create(
			SquadRules.POST_DEF, 1, Vector2i(x, StartingBase.SPINE_ROW + 1)
		)
		if command.validate(_state).is_ok:
			_submit(command)
			post = _state.base.rooms[_state.base.rooms.size() - 1]
			break
	assert_object(post).is_not_null()
	for guard: int in 60 * TimeMath.TICKS_PER_DAY:
		if post.is_built():
			break
		_ticks(1)
	for index: int in count:
		var soldier := PersonState.new()
		soldier.id = StringName("soldier_%d" % index)
		soldier.name = "Soldier %d" % index
		soldier.role = SquadRules.SOLDIER
		soldier.skill = 5
		soldier.room_id = post.id
		_state.staff.people.append(soldier)
	_ticks(1)
	return _state.security.squad_of(post.id)


func test_a_sabotage_is_beaten_at_a_sealed_door() -> void:
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	var door: DoorState = _seal_on_path_to(plant)
	_submit(SetDoorCommand.create(door.level, door.cell, DoorState.Mode.OPEN))
	var squad: SquadState = _squad(6)
	_submit(OrderSquadCommand.create(squad.post_room, SquadState.Order.MOVE, _waiting))
	_ticks(60)
	assert_that(squad.pos).is_equal(_waiting)
	_submit(SetDoorCommand.create(door.level, door.cell, DoorState.Mode.SEALED))
	_incursion(&"incursion_test_sabotage")
	_until_over()
	assert_bool(_state.base.doors.has(door)).is_true()
	assert_bool(plant.damaged).is_false()
	assert_str(str(_ended.back()["outcome"])).is_equal("stopped")


func test_a_theft_gets_away_with_an_artefact() -> void:
	var record := ArtefactRecord.new()
	record.uid = 77
	record.artefact = &"artefact_x"
	_state.artefacts.items.append(record)
	_incursion(&"incursion_test_theft")
	_until_over()
	assert_object(ArtefactRules.find(_state, 77)).is_null()
	assert_array(_ended.back()["lost"]).has_size(1)


func test_an_assault_overruns_the_base_and_the_last_save_loads() -> void:
	var service: SaveServiceScript = auto_free(SaveServiceScript.new())
	service.saves_dir = "user://m4c_flow_%d" % Time.get_ticks_usec()
	assert_bool(service.save_game(_state, &"last").is_ok).is_true()
	_incursion(&"incursion_test_assault")
	_until_over(4000)
	assert_bool(_state.outcome.has_failed()).is_true()
	assert_str(String(_state.outcome.cause)).is_equal("overrun")
	var refused: CommandResult = _simulation.submit(DebugCheatCommand.create(&"charge"))
	assert_bool(refused.is_ok).is_false()
	var loaded: Result = service.load_game(&"last", _defs)
	assert_bool(loaded.is_ok).is_true()
	var state: GameState = loaded.value
	assert_bool(state.outcome.has_failed()).is_false()
	assert_bool(state.incursion.is_active()).is_false()


func test_the_shutter_stops_a_wave() -> void:
	_submit(DebugCheatCommand.create(&"unlock_all_research"))
	var gate: RoomState = _room(StartingBase.GATE_ROOM_DEF)
	_submit(InstallCommand.create(gate.id, ShutterRules.DEF_ID))
	_ticks(2 * TimeMath.TICKS_PER_DAY)
	_charged_bank()
	_submit(SetShutterCommand.create(true))
	_submit(DebugCheatCommand.create(&"incursion", &"incursion_test_sabotage"))
	_submit(DebugCheatCommand.create(&"skip_warning"))
	_until_over()
	assert_bool(_state.incursion.is_active()).is_false()
	assert_bool(_room(ObjectiveRules.POWER_PLANT_DEF).damaged).is_false()
	assert_str(str(_ended.back()["outcome"])).is_equal("shutter")


func test_zero_confidence_for_a_week_only_warns() -> void:
	var warned: Array[StringName] = []
	_simulation.event_posted.connect(
		func(event_name: StringName, args: Array) -> void:
			if event_name == &"committee_warning" and not args.is_empty():
				warned.append(StringName(str(args[0])))
	)
	_submit(DebugCheatCommand.create(&"confidence", &"", 0))
	_ticks(8 * TimeMath.TICKS_PER_DAY)
	assert_int(_state.outcome.zero_confidence_days).is_greater_equal(7)
	assert_bool(_state.outcome.has_failed()).is_false()
	assert_array(warned).contains([&"would_close"])


func test_a_moth_is_researched_racked_ordered_and_launched() -> void:
	assert_bool(MothRules.has_rack(_state)).is_false()
	_submit(DebugCheatCommand.create(&"unlock_all_research"))
	var gate: RoomState = _room(StartingBase.GATE_ROOM_DEF)
	_submit(InstallCommand.create(gate.id, MothRules.RACK_DEF))
	for guard: int in 10 * TimeMath.TICKS_PER_DAY:
		if MothRules.has_rack(_state):
			break
		_ticks(1)
	assert_bool(MothRules.has_rack(_state)).is_true()
	_submit(OrderMothCommand.new())
	_ticks(TimeMath.TICKS_PER_DAY + 2)
	assert_int(MothRules.owned(_state)).is_equal(1)
	_charged_bank()
	_submit(DialCommand.create(DialFixture.address_of(_state.galaxy, &"world_hearth")))
	_ticks(_state.balance.dial_duration_ticks + 1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_submit(LaunchMothCommand.new())
	assert_int(MothRules.owned(_state)).is_equal(1)


func test_a_sentry_gun_holds_its_room() -> void:
	_submit(DebugCheatCommand.create(&"unlock_all_research"))
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	_submit(InstallCommand.create(plant.id, SentryRules.SENTRY))
	_ticks(3 * TimeMath.TICKS_PER_DAY)
	_state.incursion_defs[&"incursion_test_sabotage"].group_counts = [2]
	_incursion(&"incursion_test_sabotage")
	_until_over()
	assert_bool(plant.damaged).is_false()
	assert_str(str(_ended.back()["outcome"])).is_not_equal("done")
