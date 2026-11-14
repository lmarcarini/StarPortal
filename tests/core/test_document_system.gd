## Tests for DocumentSystem and the AT_START delivery of GameSetup.build_new(): start documents
## in id order and only for a new game; ON_FIRST_LOCK documents delivered only when the pole
## camera takes the world's horizon record (never on the lock alone), once per world (relock,
## save and reload), nothing when the wormhole closes first, one pause request per delivery tick.
## Bible: technical-architecture.md#narrative-and-event-scripting,
## gate-and-address-spec.md#where-addresses-come-from,
## game-design.md#base-building-and-power (the pole camera, horizon record)
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


## Dials world [param id] and runs until the dial resolves, leaving any wormhole open, with
## the clock paused.
func _dial(id: StringName) -> void:
	_state.clock.is_paused = true
	if _state.gate.mode == GateState.RingMode.LOCKED:
		_simulation.submit(CloseWormholeCommand.new())
	var address: GateAddress = DialFixture.address_of(_state.galaxy, id)
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	_run(2)


## Runs [param ticks] ticks; the clock stays paused between them, so commands apply at once.
func _run(ticks: int) -> void:
	for _tick: int in ticks:
		_simulation.advance_tick()


## Extends the pole camera; returns the result.
func _extend() -> CommandResult:
	return _simulation.submit(ExtendPoleCameraCommand.new())


## Saves [member _state] to JSON, loads it, and rebuilds the simulation around the copy.
func _reload() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	loaded.balance = _state.balance
	loaded.galaxy = _state.galaxy
	loaded.room_defs = _state.room_defs
	loaded.clock.is_paused = true
	_state = loaded
	_simulation = _simulation_over(loaded)


## A lock alone delivers nothing, however long the wormhole stays open.
func test_lock_alone_delivers_nothing() -> void:
	_dial(DialFixture.OPEN_ID)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_run(20)
	assert_array(_state.archive.received).is_empty()
	assert_array(_pauses).is_empty()


## Extending delivers both of the world's documents in id order on the camera's fifth tick, after
## horizon_record_taken and the report's four world_fact_raised, each posted once, with one
## pause request; the record is marked taken.
func test_extending_delivers_the_worlds_documents_once() -> void:
	_dial(DialFixture.OPEN_ID)
	_events.clear()
	assert_bool(_extend().is_ok).is_true()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS - 1)
	assert_array(_state.archive.received).is_empty()
	assert_bool(_state.worlds.is_pole_camera_out()).is_true()
	var record_tick: int = _state.clock.tick
	_run(1)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	(
		assert_array(_events)
		. is_equal(
			[
				&"horizon_record_taken",
				&"world_fact_raised",
				&"world_fact_raised",
				&"world_fact_raised",
				&"world_fact_raised",
				&"document_received",
				&"document_received",
			]
		)
	)
	assert_array(_pauses).is_equal([&"document_received"])
	assert_int(_state.archive.received_tick[&"doc_a_open"]).is_equal(record_tick)
	assert_bool(_state.worlds.is_horizon_record_taken(DialFixture.OPEN_ID)).is_true()
	assert_bool(_state.worlds.is_pole_camera_out()).is_false()
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## The record raises the world's report: atmosphere, temperature and radiation to the pole
## camera's confidence and the threat to POOR, all from the pole camera; a second record changes
## nothing (m3-beyond-the-ring.md section 2).
func test_record_raises_the_report() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	var report: WorldReport = _state.worlds.report_of(DialFixture.OPEN_ID)
	for fact: WorldReport.Fact in [
		WorldReport.Fact.ATMOSPHERE, WorldReport.Fact.TEMPERATURE, WorldReport.Fact.RADIATION
	]:
		assert_int(report.confidence_of(fact)).is_equal(WorldProgress.POLE_CAMERA_CONFIDENCE)
		assert_str(report.entry_of(fact).source).is_equal(WorldProgress.POLE_CAMERA_SOURCE)
	assert_int(report.confidence_of(WorldReport.Fact.THREAT)).is_equal(WorldReport.Confidence.POOR)
	assert_int(report.confidence_of(WorldReport.Fact.LIFE)).is_equal(WorldReport.Confidence.NONE)
	var before: Dictionary = _state.worlds.to_dict()
	WorldProgress.record_horizon(_state, DialFixture.OPEN_ID)
	assert_dict(_state.worlds.to_dict()).is_equal(before)


## A document of another world, or with NEVER, does not arrive.
func test_other_worlds_and_never_do_not_arrive() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_bool(_state.archive.has_document(&"doc_guarded")).is_false()
	assert_bool(_state.archive.has_document(&"doc_never")).is_false()


## A hostile lock is a lock.
func test_hostile_lock_delivers() -> void:
	_dial(DialFixture.GUARDED_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_array(_state.archive.received).is_equal([&"doc_guarded"])


## A world with no documents still gives its record, with no pause.
func test_world_without_documents_gives_a_record_and_no_pause() -> void:
	_documents = []
	_simulation = _simulation_over(_state)
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_bool(_state.worlds.is_horizon_record_taken(DialFixture.OPEN_ID)).is_true()
	assert_int(_events.count(&"horizon_record_taken")).is_equal(1)
	assert_array(_pauses).is_empty()


## A second lock of the world refuses the camera with already_taken and delivers nothing new.
func test_second_lock_is_already_taken() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	_events.clear()
	_pauses.clear()
	_dial(DialFixture.OPEN_ID)
	assert_str(_extend().error_code).is_equal(&"already_taken")
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	assert_int(_events.count(&"document_received")).is_equal(0)
	assert_array(_pauses).is_empty()


## The player closing the wormhole mid-extension pulls the camera back with nothing taken; a
## later lock can complete it.
func test_close_mid_extension_delivers_nothing_and_a_later_lock_completes() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS - 1)
	_simulation.submit(CloseWormholeCommand.new())
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_array(_state.archive.received).is_empty()
	assert_bool(_state.worlds.is_pole_camera_out()).is_false()
	assert_bool(_state.worlds.is_horizon_record_taken(DialFixture.OPEN_ID)).is_false()
	assert_int(_events.count(&"horizon_record_taken")).is_equal(0)
	_dial(DialFixture.OPEN_ID)
	assert_bool(_extend().is_ok).is_true()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])


## A time-out on the camera's last tick closes the wormhole first: nothing is taken.
func test_timeout_on_the_last_tick_delivers_nothing() -> void:
	_dial(DialFixture.OPEN_ID)
	var open_left: int = GateQueries.open_ticks_left(_state)
	_run(open_left - ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_bool(_extend().is_ok).is_true()
	_run(ExtendPoleCameraCommand.EXTEND_TICKS)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_array(_state.archive.received).is_empty()
	assert_bool(_state.worlds.is_pole_camera_out()).is_false()


## A save and reload mid-extension keeps the camera's progress: the record comes on time, once.
func test_reload_mid_extension_keeps_progress() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_run(2)
	_reload()
	assert_int(_state.worlds.pole_camera_ticks_left).is_equal(
		ExtendPoleCameraCommand.EXTEND_TICKS - 2
	)
	assert_str(_extend().error_code).is_equal(&"camera_busy")
	_run(ExtendPoleCameraCommand.EXTEND_TICKS - 3)
	assert_array(_state.archive.received).is_empty()
	_run(1)
	assert_array(_state.archive.received).is_equal([&"doc_a_open", &"doc_b_open"])
	_reload()
	_dial(DialFixture.OPEN_ID)
	assert_str(_extend().error_code).is_equal(&"already_taken")


## The delivery pauses a running clock on the record's tick.
func test_running_clock_pauses_on_delivery() -> void:
	_dial(DialFixture.OPEN_ID)
	_extend()
	_state.clock.is_paused = false
	var ticks: int = 0
	while _pauses.is_empty() and ticks < 10:
		_simulation.advance_tick()
		ticks += 1
	assert_array(_pauses).is_equal([&"document_received"])
	assert_int(ticks).is_equal(ExtendPoleCameraCommand.EXTEND_TICKS)


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
	assert_array(ids).is_equal(
		[
			&"power",
			&"gate",
			&"conversations",
			&"requests",
			&"documents",
			&"probes",
			&"expedition",
			&"economy",
			&"construction",
			&"research",
			&"recruitment",
			&"staff_care",
			&"factions",
			&"artefacts",
			&"security",
			&"incursion",
			&"outcome"
		]
	)
