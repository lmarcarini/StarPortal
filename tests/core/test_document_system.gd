## Tests for DocumentSystem and the AT_START delivery of GameSetup.build_new(): start documents
## in id order and only for a new game, ON_FIRST_LOCK documents delivered on the tick their
## world locks and never twice (relock, save and reload), one pause request per delivery tick.
## Bible: technical-architecture.md#narrative-and-event-scripting,
## gate-and-address-spec.md#where-addresses-come-from
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation
var _documents: Array[DocumentDef] = []
var _events: Array[StringName] = []
var _pauses: Array[StringName] = []


func before_test() -> void:
	_documents = [
		_document(&"doc_b_open", DocumentDef.Arrival.ON_FIRST_LOCK, DialFixture.OPEN_ID),
		_document(&"doc_a_open", DocumentDef.Arrival.ON_FIRST_LOCK, DialFixture.OPEN_ID),
		_document(&"doc_guarded", DocumentDef.Arrival.ON_FIRST_LOCK, DialFixture.GUARDED_ID),
		_document(&"doc_never", DocumentDef.Arrival.NEVER, &""),
	]
	_state = DialFixture.state(null, true)
	_simulation = _simulation_over(_state)


func _document(id: StringName, arrival: DocumentDef.Arrival, world: StringName) -> DocumentDef:
	var def := DocumentDef.new()
	def.id = id
	def.arrival = arrival
	def.arrival_world_id = world
	return def


## A Simulation over [param game] with the real systems and the test documents, recording
## events and pause requests.
func _simulation_over(game: GameState) -> Simulation:
	_events.clear()
	_pauses.clear()
	var systems: Array[SimSystem] = [
		PowerSystem.new(game.balance), GateSystem.new(), DocumentSystem.new(_documents)
	]
	var simulation := Simulation.new(game, systems)
	simulation.event_posted.connect(
		func(event_name: StringName, _args: Array) -> void: _events.append(event_name)
	)
	simulation.pause_requested.connect(func(reason: StringName) -> void: _pauses.append(reason))
	return simulation


## Dials world [param id] and runs until the dial resolves, then closes any wormhole.
func _dial(id: StringName) -> void:
	_state.clock.is_paused = true
	var address: GateAddress = DialFixture.address_of(_state.galaxy, id)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	_state.clock.is_paused = false
	_simulation.advance_tick()
	_simulation.advance_tick()
	_state.clock.is_paused = true
	if _state.gate.mode == GateState.RingMode.LOCKED:
		_simulation.submit(CloseWormholeCommand.new())


## Saves [member _state] to JSON, loads it, and rebuilds the simulation around the copy.
func _reload() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	loaded.balance = _state.balance
	loaded.galaxy = _state.galaxy
	loaded.power.capacity_mwh = DialFixture.CAPACITY_MWH
	loaded.power.stored_mwh = DialFixture.CAPACITY_MWH
	loaded.clock.is_paused = true
	_state = loaded
	_simulation = _simulation_over(loaded)


## Both of a world's documents arrive on the lock tick, in id order, each posted once, with
## one pause request.
func test_lock_delivers_the_worlds_documents_with_one_pause() -> void:
	_dial(DialFixture.OPEN_ID)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	assert_int(_events.count(&"document_received")).is_equal(2)
	assert_array(_pauses).is_equal([&"document_received"])
	var lock_tick: int = _state.gate.dial_log[0].tick
	assert_int(_state.archive.received_tick[&"doc_a_open"]).is_equal(lock_tick - 1)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## A document of another world, or with NEVER, does not arrive.
func test_other_worlds_and_never_do_not_arrive() -> void:
	_dial(DialFixture.OPEN_ID)
	assert_bool(_state.archive.has_document(&"doc_guarded")).is_false()
	assert_bool(_state.archive.has_document(&"doc_never")).is_false()


## A hostile lock is a lock.
func test_hostile_lock_delivers() -> void:
	_dial(DialFixture.GUARDED_ID)
	assert_array(_state.archive.received).is_equal([&"doc_guarded"])


## A failed dial delivers nothing and requests no pause.
func test_failed_dial_delivers_nothing() -> void:
	_dial(DialFixture.BURIED_ID)
	assert_array(_state.archive.received).is_empty()
	assert_array(_pauses).is_empty()


## Locking the world again delivers nothing new and requests no pause.
func test_relock_delivers_nothing() -> void:
	_dial(DialFixture.OPEN_ID)
	_events.clear()
	_pauses.clear()
	_dial(DialFixture.OPEN_ID)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	assert_int(_events.count(&"document_received")).is_equal(0)
	assert_array(_pauses).is_empty()


## Lock, save, reload, lock again, and reload before the first lock: each document arrives
## exactly once.
func test_reload_between_locks_never_redelivers() -> void:
	_dial(DialFixture.OPEN_ID)
	_reload()
	assert_int(_events.count(&"document_received")).is_equal(0)
	_simulation.advance_tick()
	_simulation.advance_tick()
	assert_int(_events.count(&"document_received")).is_equal(0)
	_dial(DialFixture.OPEN_ID)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	assert_int(_events.count(&"document_received")).is_equal(0)
	assert_array(_pauses).is_empty()
	_dial(DialFixture.GUARDED_ID)
	_reload()
	_dial(DialFixture.GUARDED_ID)
	(
		assert_array(
			_state.archive.received.filter(
				func(id: StringName) -> bool: return id == &"doc_guarded"
			)
		)
		. has_size(1)
	)


## A reload that happens after the lock but before the next tick (statuses saved as LOCKED,
## Dial Log holding the lock) delivers nothing more: only the lock tick itself delivers.
func test_reload_with_a_lock_in_the_log_and_no_archive_entry_waits_for_a_new_lock() -> void:
	_dial(DialFixture.OPEN_ID)
	_state.archive = ArchiveState.new()
	_reload()
	_simulation.advance_tick()
	assert_array(_state.archive.received).is_empty()


## The delivery posts the pause on the lock tick of a running clock, which pauses it.
func test_running_clock_pauses_on_delivery() -> void:
	var previous_clock: ClockState = _state.clock
	_state.clock.is_paused = true
	var address: GateAddress = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)
	_simulation.submit(DialCommand.create(address))
	assert_int(previous_clock.tick).is_equal(0)
	var ticks: int = 0
	while _pauses.is_empty() and ticks < 10:
		_simulation.advance_tick()
		ticks += 1
	assert_array(_pauses).is_equal([&"document_received"])
	assert_int(ticks).is_equal(2)


# --- GameSetup -------------------------------------------------------------


func _setup_defs() -> GameDefs:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	defs.documents = [
		_document(&"doc_start_b", DocumentDef.Arrival.AT_START, &""),
		_document(&"doc_start_a", DocumentDef.Arrival.AT_START, &""),
		_document(&"doc_other", DocumentDef.Arrival.ON_FIRST_LOCK, &"world_cairn"),
	]
	return defs


## A new game holds its AT_START documents at tick 0 in id order, each posted once.
func test_build_new_delivers_start_documents() -> void:
	var defs: GameDefs = _setup_defs()
	var state: GameState = GameState.new_game(11, defs.balance)
	var built: Result = GameSetup.build_new(state, defs)
	assert_bool(built.is_ok).is_true()
	assert_array(state.archive.received).is_equal([&"doc_start_a", &"doc_start_b"])
	assert_int(state.archive.received_tick[&"doc_start_a"]).is_equal(0)
	var names: Array[StringName] = []
	for event: SimEvent in state.events.drain():
		names.append(event.name)
	assert_array(names).is_equal([&"document_received", &"document_received"])


## build() on a new or loaded state never delivers start documents, and a loaded game that
## was built with build_new() keeps its Archive unchanged.
func test_build_and_load_never_deliver_start_documents() -> void:
	var defs: GameDefs = _setup_defs()
	var fresh: GameState = GameState.new_game(11, defs.balance)
	assert_bool(GameSetup.build(fresh, defs).is_ok).is_true()
	assert_array(fresh.archive.received).is_empty()
	var original: GameState = GameState.new_game(11, defs.balance)
	GameSetup.build_new(original, defs)
	var data: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	assert_bool(GameSetup.build(loaded, defs).is_ok).is_true()
	assert_array(loaded.archive.received).is_equal([&"doc_start_a", &"doc_start_b"])
	assert_int(loaded.events.size()).is_equal(0)


## A failed build_new() delivers nothing.
func test_failed_build_new_delivers_nothing() -> void:
	var defs: GameDefs = _setup_defs()
	defs.anchors = null
	var state: GameState = GameState.new_game(11, defs.balance)
	assert_bool(GameSetup.build_new(state, defs).is_ok).is_false()
	assert_array(state.archive.received).is_empty()


## The built simulation runs the documents system last.
func test_documents_system_runs_after_gate() -> void:
	var defs: GameDefs = _setup_defs()
	var state: GameState = GameState.new_game(11, defs.balance)
	var simulation: Simulation = GameSetup.build(state, defs).value
	var ids: Array[StringName] = []
	for system: SimSystem in simulation._systems:
		ids.append(system.get_id())
	assert_array(ids).is_equal([&"power", &"gate", &"documents"])
