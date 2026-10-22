## Tests for IntelSystem on a new game built from the real data/ content: the three opening
## dossiers arrive at ticks 0, 1440 and 2880 with unique, sequential clue and dossier ids
## stamped with the delivery tick; each clue posts clue_received and each delivery asks to
## pause with &"dossier_received"; a save and load between deliveries keeps the schedule and
## ends in the same state as an uninterrupted run.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#puzzle-tuning-rules, technical-architecture.md#save-system
extends GdUnitTestSuite

const SEED: int = 5757
## A tick after the third dossier has arrived.
const END_TICK: int = 2 * TimeMath.TICKS_PER_DAY + 10

var _defs: GameDefs
var _events: Array[Array] = []
var _pauses: Array[Array] = []


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_events.clear()
	_pauses.clear()


func _new_simulation() -> Simulation:
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, _defs.balance), _defs)
	var simulation: Simulation = built.value
	simulation.event_posted.connect(_on_event_posted.bind(simulation))
	simulation.pause_requested.connect(_on_pause_requested.bind(simulation))
	return simulation


func _on_event_posted(name: StringName, args: Array, simulation: Simulation) -> void:
	_events.append([simulation.state.clock.tick, name, args])


func _on_pause_requested(reason: StringName, simulation: Simulation) -> void:
	_pauses.append([simulation.state.clock.tick, reason])


func _run_to(simulation: Simulation, tick: int) -> void:
	while simulation.state.clock.tick < tick:
		simulation.advance_tick()


## The systems tick power, gate, then intel.
func test_intel_ticks_after_gate() -> void:
	var simulation: Simulation = _new_simulation()
	var ids: Array[StringName] = []
	for system: SimSystem in simulation._systems:
		ids.append(system.get_id())
	assert_array(ids).is_equal([&"power", &"gate", &"intel"])


## Dossier 1 arrives on the first tick (tick 0), nothing more until day 2; the clues are
## numbered from clue_0001 in dossier_01, received at tick 0, true and about the target.
func test_first_dossier_arrives_at_tick_zero() -> void:
	var simulation: Simulation = _new_simulation()
	var intel: IntelState = simulation.state.intel
	var first_target: StringName = _target_due_at(intel, 0)
	assert_int(intel.clues.size()).is_equal(0)
	simulation.advance_tick()
	assert_int(intel.clues.size()).is_greater_equal(3)
	assert_bool(intel.scheduled_dossiers.has(first_target)).is_false()
	assert_int(intel.scheduled_dossiers.size()).is_equal(2)
	var origin: int = simulation.state.galaxy.home().origin_glyph
	var address: GateAddress = simulation.state.galaxy.address_of(first_target, origin)
	for index: int in intel.clues.size():
		var clue: ClueRecord = intel.clues[index]
		assert_str(String(clue.id)).is_equal("clue_%04d" % (index + 1))
		assert_str(String(clue.dossier_id)).is_equal("dossier_01")
		assert_int(clue.received_tick).is_equal(0)
		assert_str(String(clue.target_world_id)).is_equal(String(first_target))
		for constraint: AddressConstraint in clue.constraints:
			assert_bool(constraint.is_satisfied_by(address)).is_true()
	var count: int = ClueGenerator.count_candidates(intel.clues, origin)
	assert_int(count).is_between(1, OpeningScenario.MAX_CANDIDATES)
	_run_to(simulation, TimeMath.TICKS_PER_DAY)
	assert_int(intel.next_dossier_number).is_equal(2)


## By day 3 all three dossiers are in: ids dossier_01..03, clue ids unique and sequential,
## received at the start of their day, counters moved on, nothing left scheduled, and the
## state still validates after a JSON round trip.
func test_three_dossiers_by_day_three() -> void:
	var simulation: Simulation = _new_simulation()
	_run_to(simulation, END_TICK)
	var intel: IntelState = simulation.state.intel
	assert_dict(intel.scheduled_dossiers).is_empty()
	assert_int(intel.next_dossier_number).is_equal(4)
	assert_int(intel.next_clue_number).is_equal(intel.clues.size() + 1)
	var day_of_dossier: Dictionary[String, int] = {
		"dossier_01": 0, "dossier_02": 1, "dossier_03": 2
	}
	var seen: Dictionary[StringName, bool] = {}
	for index: int in intel.clues.size():
		var clue: ClueRecord = intel.clues[index]
		assert_str(String(clue.id)).is_equal("clue_%04d" % (index + 1))
		assert_bool(seen.has(clue.id)).is_false()
		seen[clue.id] = true
		assert_bool(day_of_dossier.has(String(clue.dossier_id))).is_true()
		var day: int = day_of_dossier[String(clue.dossier_id)]
		assert_int(clue.received_tick).is_equal(day * TimeMath.TICKS_PER_DAY)
	var data: Dictionary = JSON.parse_string(JSON.stringify(simulation.state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()


## Every clue posts clue_received once, at its delivery tick, and every delivery asks once to
## pause with &"dossier_received".
func test_events_and_pause_requests() -> void:
	var simulation: Simulation = _new_simulation()
	_run_to(simulation, END_TICK)
	var received: Array[StringName] = []
	for event: Array in _events:
		if event[1] == &"clue_received":
			var args: Array = event[2]
			received.append(args[0])
	var expected: Array[StringName] = []
	for clue: ClueRecord in simulation.state.intel.clues:
		expected.append(clue.id)
	assert_array(received).is_equal(expected)
	var after_delivery: Array = [1, TimeMath.TICKS_PER_DAY + 1, 2 * TimeMath.TICKS_PER_DAY + 1]
	var expected_pauses: Array[Array] = []
	for tick: int in after_delivery:
		expected_pauses.append([tick, IntelSystem.PAUSE_REASON])
	assert_array(_pauses).is_equal(expected_pauses)


## Saving and loading between the first and second dossier keeps the two still scheduled,
## and the loaded game ends in exactly the state of an uninterrupted run.
func test_save_and_load_mid_way_keeps_the_schedule() -> void:
	var uninterrupted: Simulation = _new_simulation()
	_run_to(uninterrupted, END_TICK)
	var first: Simulation = _new_simulation()
	_run_to(first, TimeMath.TICKS_PER_DAY / 2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(first.state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	assert_dict(loaded.intel.scheduled_dossiers).is_equal(first.state.intel.scheduled_dossiers)
	assert_int(loaded.intel.scheduled_dossiers.size()).is_equal(2)
	var built: Result = GameSetup.build(loaded, _defs)
	var resumed: Simulation = built.value
	_run_to(resumed, END_TICK)
	assert_dict(resumed.state.to_dict()).is_equal(uninterrupted.state.to_dict())


## A dossier for an unknown world is dropped from the schedule without clues, and only the
## known ones are delivered.
func test_unknown_world_delivers_nothing() -> void:
	var simulation: Simulation = _new_simulation()
	var intel: IntelState = simulation.state.intel
	intel.scheduled_dossiers.clear()
	intel.scheduled_dossiers[&"world_nowhere"] = 0
	simulation.advance_tick()
	assert_dict(intel.scheduled_dossiers).is_empty()
	assert_int(intel.clues.size()).is_equal(0)


## The world whose dossier is due at [param tick].
func _target_due_at(intel: IntelState, tick: int) -> StringName:
	for world_id: StringName in intel.scheduled_dossiers:
		if intel.scheduled_dossiers[world_id] == tick:
			return world_id
	return &""
