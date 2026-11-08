## Tests for the MOTH's scans on a LOW world (no losses): battery minutes simulated tick by tick,
## each scan's result, the recall, the battery running out and the rack's automatic reorder.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH, scans, losses)
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const WORLD := ProbeFixture.WORLD_ID

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = ProbeFixture.state()
	_simulation = ProbeFixture.simulation(_state)
	ProbeFixture.open(_simulation)
	assert_bool(_simulation.submit(LaunchMothCommand.new()).is_ok).is_true()


## Runs [param scan] and returns how many ticks it took to finish.
func _scan(scan: MothRules.Scan, target: StringName = &"") -> int:
	var result: CommandResult = _simulation.submit(MothScanCommand.create(scan, target))
	assert_bool(result.is_ok).is_true()
	var ticks: int = 0
	while _state.probes.moth != null and _state.probes.moth.is_scanning() and ticks < 100:
		_simulation.advance_tick()
		ticks += 1
	return ticks


func _confidence(fact: WorldReport.Fact) -> WorldReport.Confidence:
	return _state.worlds.report_of(WORLD).confidence_of(fact)


## A full battery is 20 minutes; each scan takes its battery minutes as ticks (5, 4, 4, 2);
## Look around, a Close look, Ring and Sky leave 5, and a 2-minute recall leaves 3 to spare and
## puts the drone back in the rack, making the world Probed.
func test_battery_plan_and_recall() -> void:
	assert_int(_state.probes.moth.battery_left).is_equal(20)
	assert_int(_state.probes.rack).is_equal(1)
	assert_int(_scan(MothRules.Scan.LOOK_AROUND)).is_equal(5)
	assert_int(_scan(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID)).is_equal(4)
	assert_int(_scan(MothRules.Scan.RING)).is_equal(4)
	assert_int(_scan(MothRules.Scan.SKY)).is_equal(2)
	assert_int(_state.probes.moth.battery_left).is_equal(5)
	assert_int(_state.worlds.status_of(WORLD)).is_equal(WorldsState.WorldStatus.LOCKED)
	_simulation.submit(MothScanCommand.create(MothRules.Scan.RECALL))
	ProbeFixture.advance(_simulation, 1)
	assert_int(_state.probes.moth.battery_left).is_equal(4)
	ProbeFixture.advance(_simulation, 1)
	assert_object(_state.probes.moth).is_null()
	assert_int(_state.probes.rack).is_equal(2)
	assert_array(_state.probes.reorders).is_empty()
	assert_int(_state.worlds.status_of(WORLD)).is_equal(WorldsState.WorldStatus.PROBED)


## A second Close look leaves 1 minute, too little to recall: the drone is lost when the
## battery runs out, its scans are kept, and a replacement is ordered ($150k) for a day later.
func test_battery_runs_out() -> void:
	_scan(MothRules.Scan.LOOK_AROUND)
	_scan(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID)
	_scan(MothRules.Scan.RING)
	_scan(MothRules.Scan.SKY)
	var funds: int = _state.budget.funds_k
	_scan(MothRules.Scan.CLOSE_LOOK, ProbeFixture.FOOTPRINTS_ID)
	assert_object(_state.probes.moth).is_null()
	assert_int(_state.probes.rack).is_equal(1)
	assert_int(funds - _state.budget.funds_k).is_equal(150)
	assert_int(_confidence(WorldReport.Fact.TARGETS)).is_equal(WorldReport.Confidence.FAIR)
	assert_int(_state.probes.photos.size()).is_equal(3)
	assert_int(_state.worlds.status_of(WORLD)).is_equal(WorldsState.WorldStatus.PROBED)
	_assert_reorder_arrives_in_a_day()


## Closing the wormhole with the MOTH out loses it; the replacement arrives a day later.
func test_wormhole_close_loses_the_drone() -> void:
	_simulation.submit(MothScanCommand.create(MothRules.Scan.LOOK_AROUND))
	ProbeFixture.advance(_simulation, 2)
	_simulation.submit(CloseWormholeCommand.new())
	ProbeFixture.advance(_simulation, 1)
	assert_object(_state.probes.moth).is_null()
	assert_int(_confidence(WorldReport.Fact.LIFE)).is_equal(WorldReport.Confidence.NONE)
	_assert_reorder_arrives_in_a_day()


func _assert_reorder_arrives_in_a_day() -> void:
	assert_int(_state.probes.reorders.size()).is_equal(1)
	var rack: int = _state.probes.rack
	ProbeFixture.advance(_simulation, TimeMath.TICKS_PER_DAY - 2)
	assert_int(_state.probes.rack).is_equal(rack)
	ProbeFixture.advance(_simulation, 2)
	assert_int(_state.probes.rack).is_equal(rack + 1)
	assert_array(_state.probes.reorders).is_empty()


## Look around raises Life, Structures, Targets and the threat to fair and lists targets.
func test_look_around() -> void:
	(
		assert_str(
			(
				MothScanCommand
				. create(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID)
				. validate(_state)
				. error_code
			)
		)
		. is_equal(&"unknown_target")
	)
	_scan(MothRules.Scan.LOOK_AROUND)
	for fact: WorldReport.Fact in [
		WorldReport.Fact.LIFE,
		WorldReport.Fact.STRUCTURES,
		WorldReport.Fact.TARGETS,
		WorldReport.Fact.THREAT
	]:
		assert_int(_confidence(fact)).is_equal(WorldReport.Confidence.FAIR)
	(
		assert_str(MothScanCommand.create(MothRules.Scan.LOOK_AROUND).validate(_state).error_code)
		. is_equal(&"already_done")
	)


## A Close look at an object takes its photo, marks it recoverable in the saved world state
## (not on the shared WorldTarget) and copies its marks into the Archive; a land feature is
## photographed only. A recoverable target stays recoverable until recovered (Recover retries).
func test_close_look() -> void:
	_scan(MothRules.Scan.LOOK_AROUND)
	_scan(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID)
	assert_bool(_state.worlds.targets.is_recoverable(WORLD, ProbeFixture.ANCHOR_ID)).is_true()
	assert_bool(_state.archive.has_document(ProbeFixture.MARKS_DOCUMENT_ID)).is_true()
	assert_dict(_state.probes.photos[0]).contains_key_value("kind", "close_look")
	assert_dict(_state.probes.photos[0]).contains_key_value("target_id", "anchor")
	_scan(MothRules.Scan.CLOSE_LOOK, ProbeFixture.FOOTPRINTS_ID)
	assert_int(_state.worlds.targets.state_of(WORLD, ProbeFixture.FOOTPRINTS_ID)).is_equal(
		TargetStates.State.NONE
	)
	(
		assert_bool(
			WorldProgress.raise_target(
				_state, WORLD, ProbeFixture.ANCHOR_ID, TargetStates.State.RECOVERABLE
			)
		)
		. is_false()
	)
	assert_bool(_state.worlds.targets.is_recoverable(WORLD, ProbeFixture.ANCHOR_ID)).is_true()
	WorldProgress.raise_target(_state, WORLD, ProbeFixture.ANCHOR_ID, TargetStates.State.RECOVERED)
	assert_bool(_state.worlds.targets.is_recoverable(WORLD, ProbeFixture.ANCHOR_ID)).is_false()


## Sky takes a sky photo; Ring adds the console's older log (1 or 2 addresses beyond those the
## console lists) to the Address Book, once per world.
func test_sky_and_ring() -> void:
	_scan(MothRules.Scan.SKY)
	assert_dict(_state.probes.photos[0]).contains_key_value("kind", "sky")
	var older: Array[StringName] = MothRules.older_log_worlds(WORLD, _state.galaxy)
	assert_int(older.size()).is_between(1, 2)
	var listed: Array[StringName] = ConsoleLog.listed_worlds(WORLD, _state.galaxy)
	for world_id: StringName in older:
		assert_bool(listed.has(world_id)).is_false()
	var book_size: int = _state.address_book.entries.size()
	_scan(MothRules.Scan.RING)
	assert_int(_state.address_book.entries.size() - book_size).is_equal(older.size())
	assert_str(MothScanCommand.create(MothRules.Scan.RING).validate(_state).error_code).is_equal(
		&"already_done"
	)


## Refusals: a running scan, too little battery, and no drone out or an empty rack.
func test_refusals() -> void:
	_simulation.submit(MothScanCommand.create(MothRules.Scan.SKY))
	assert_str(MothScanCommand.create(MothRules.Scan.RING).validate(_state).error_code).is_equal(
		&"scan_running"
	)
	ProbeFixture.advance(_simulation, 2)
	_state.probes.moth.battery_left = 3
	(
		assert_str(MothScanCommand.create(MothRules.Scan.LOOK_AROUND).validate(_state).error_code)
		. is_equal(&"battery_low")
	)
	assert_str(LaunchMothCommand.new().validate(_state).error_code).is_equal(&"moth_busy")
	_state.probes.moth = null
	_state.probes.rack = 0
	assert_str(LaunchMothCommand.new().validate(_state).error_code).is_equal(&"rack_empty")
	assert_str(MothScanCommand.create(MothRules.Scan.SKY).validate(_state).error_code).is_equal(
		&"no_moth"
	)
