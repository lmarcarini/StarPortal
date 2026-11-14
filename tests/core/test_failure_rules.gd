## Failure states (M4c-14): Overrun after 30 ticks of intruders alone in the Control Room
## ends the game for good (no ticks, no commands, no autosave); Shutdown and Bankruptcy are
## counted, warned about and only say what would happen; counters reset; the setting off
## stops everything; no Control Room, no Overrun.
## Bible: docs/content/m4c-incursions.md section 8
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _events: Array[StringName] = []
var _warnings: Array = []


func before_test() -> void:
	_state = GameState.new_game(8, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_simulation.event_posted.connect(_on_event)
	_events.clear()
	_warnings.clear()


func _on_event(event_name: StringName, args: Array) -> void:
	_events.append(event_name)
	if event_name == &"committee_warning":
		_warnings.append(args[0])


func _collect() -> void:
	for event: SimEvent in _state.events.drain():
		if event.name == &"committee_warning":
			_warnings.append(event.args[0])


func _occupy_control_room() -> void:
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 1000
	unit.attack = 0.0
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [unit.id]
	def.group_counts = [1]
	def.objective = &"assault"
	_state.incursion_defs[def.id] = def
	IncursionRules.start(_state, def.id)
	IncursionRules.breach(_state)
	var control: RoomState = _state.base.find_room(ObjectiveRules.target_room(_state, &"assault"))
	_state.incursion.groups[0].move_to(Vector3i(control.origin.x, control.origin.y, control.level))


func test_overrun_ends_the_game_for_good() -> void:
	_occupy_control_room()
	var system := OutcomeSystem.new()
	for index: int in 29:
		system.tick(_state)
	assert_int(FailureRules.overrun_left(_state)).is_equal(1)
	assert_bool(_state.outcome.has_failed()).is_false()
	system.tick(_state)
	assert_bool(_state.outcome.has_failed()).is_true()
	assert_str(String(_state.outcome.cause)).is_equal("overrun")
	var tick: int = _state.clock.tick
	_simulation.advance_tick()
	assert_int(_state.clock.tick).is_equal(tick)
	assert_str(String(_simulation.submit(SetFlagCommand.new()).error_code)).is_equal("game_over")
	assert_str(String(SaveService.autosave(_state).error_code)).is_equal("game_over")


func test_the_count_resets_and_the_setting_stops_it() -> void:
	_occupy_control_room()
	var system := OutcomeSystem.new()
	for index: int in 10:
		system.tick(_state)
	_state.incursion.groups[0].move_to(IncursionRules.gate_cell(_state))
	system.tick(_state)
	assert_int(_state.outcome.overrun_ticks).is_equal(0)
	_state.outcome.enabled = false
	_state.incursion.groups[0].move_to(_state.incursion.groups[0].pos())
	_occupy_control_room()
	for index: int in 40:
		system.tick(_state)
	assert_bool(_state.outcome.has_failed()).is_false()


func test_no_control_room_no_overrun() -> void:
	for room: RoomState in _state.base.rooms.duplicate():
		if room.def_id == ObjectiveRules.CONTROL_ROOM_DEF:
			_state.base.rooms.erase(room)
	assert_str(String(ObjectiveRules.target_room(_state, &"assault"))).is_empty()
	assert_bool(FailureRules.control_room_held(_state)).is_false()


func test_shutdown_and_bankruptcy_only_warn() -> void:
	var system := OutcomeSystem.new()
	_state.committee.confidence = 150
	system.on_day(_state)
	_collect()
	assert_array(_warnings).is_equal([&"confidence_20"])
	_state.committee.confidence = 0
	_state.budget.funds_k = -5
	for day: int in 31:
		system.on_day(_state)
	_collect()
	assert_int(_state.outcome.zero_confidence_days).is_equal(31)
	assert_bool(_state.outcome.has_failed()).is_false()
	assert_array(_warnings).contains([&"confidence_10", &"would_close", &"would_bankrupt"])
	var once: int = _warnings.count(&"would_close")
	system.on_day(_state)
	_collect()
	assert_int(_warnings.count(&"would_close")).is_equal(once)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_int(GameState.from_dict(data).outcome.negative_funds_days).is_equal(32)
	_state.budget.funds_k = 10
	system.on_day(_state)
	assert_int(_state.outcome.negative_funds_days).is_equal(0)
	assert_int(FailureRules.bankruptcy_left(_state)).is_equal(-1)
