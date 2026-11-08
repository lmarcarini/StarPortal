## Tests for MOTH losses, simulated through ProbeSystem: the loss rate of each scan by the
## world's true threat (LOW 0%, MED 5%, HIGH 20%, doubled for a Close look), a shot-down drone
## keeping its finished scans and raising threat confidence one step, and determinism across a
## save and load.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Losses)
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
const WORLD := ProbeFixture.WORLD_ID
const TRIALS: int = 4000


## Runs TRIALS single scans of [param scan] on a world of [param threat] and returns how many
## lost the drone. Drives ProbeSystem directly on a held-open wormhole.
func _losses(threat: WorldDef.Threat, scan: MothRules.Scan) -> int:
	var state: GameState = ProbeFixture.state(threat, 7)
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.connected_world_id = WORLD
	state.worlds.reports[WORLD] = WorldReport.new()
	state.worlds.reports[WORLD].raise(
		WorldReport.Fact.TARGETS, WorldReport.Confidence.FAIR, &"test", 0
	)
	var system := ProbeSystem.new()
	var lost: int = 0
	for trial: int in TRIALS:
		state.probes.moth = MothRun.create(WORLD)
		state.probes.reorders.clear()
		MothScanCommand.create(scan, ProbeFixture.ANCHOR_ID).apply(state)
		for minute: int in MothRules.minutes_of(scan):
			system.tick(state)
		if state.probes.reorders.size() == 1:
			lost += 1
	return lost


## Loss rates per scan by true threat: LOW never; MED about 5% (Close look 10%); HIGH about
## 20% (Close look 40%). Seeded, so the counts are exact for this seed; the bounds are about
## four standard deviations.
func test_loss_rates_by_threat() -> void:
	assert_int(_losses(WorldDef.Threat.LOW, MothRules.Scan.SKY)).is_equal(0)
	assert_int(_losses(WorldDef.Threat.LOW, MothRules.Scan.CLOSE_LOOK)).is_equal(0)
	assert_int(_losses(WorldDef.Threat.MED, MothRules.Scan.SKY)).is_between(140, 260)
	assert_int(_losses(WorldDef.Threat.MED, MothRules.Scan.CLOSE_LOOK)).is_between(320, 480)
	assert_int(_losses(WorldDef.Threat.HIGH, MothRules.Scan.RING)).is_between(680, 920)
	assert_int(_losses(WorldDef.Threat.HIGH, MothRules.Scan.CLOSE_LOOK)).is_between(1480, 1720)
	assert_int(_losses(WorldDef.Threat.HIGH, MothRules.Scan.RECALL)).is_between(680, 920)


## A drone shot down keeps its finished scans and raises the threat confidence one step:
## after the horizon record (poor) it becomes fair; with nothing known, poor.
func test_shot_down_keeps_scans_and_raises_threat() -> void:
	for start: WorldReport.Confidence in [WorldReport.Confidence.NONE, WorldReport.Confidence.POOR]:
		var outcome: GameState = _shoot_down_after_sky(start)
		var report: WorldReport = outcome.worlds.report_of(WORLD)
		assert_int(report.confidence_of(WorldReport.Fact.THREAT)).is_equal(start + 1)
		assert_int(outcome.worlds.status_of(WORLD)).is_equal(WorldsState.WorldStatus.PROBED)
		assert_int(outcome.probes.reorders.size()).is_equal(1)
	assert_int(MothRules.confidence_after_loss(WorldReport.Confidence.FAIR)).is_equal(
		WorldReport.Confidence.FAIR
	)


## On a HIGH world, scans Sky until one finishes, then Sky-like scans until the drone is shot
## down; returns the state. The finished Sky photo must survive the loss.
func _shoot_down_after_sky(start: WorldReport.Confidence) -> GameState:
	for base_seed: int in range(1, 200):
		var state: GameState = ProbeFixture.state(WorldDef.Threat.HIGH, base_seed)
		var simulation: Simulation = ProbeFixture.simulation(state)
		ProbeFixture.open(simulation)
		if start > WorldReport.Confidence.NONE:
			WorldProgress.raise_fact(
				state,
				WorldProgress.FactChange.create(WORLD, WorldReport.Fact.THREAT, start, &"test")
			)
		simulation.submit(LaunchMothCommand.new())
		simulation.submit(MothScanCommand.create(MothRules.Scan.SKY))
		ProbeFixture.advance(simulation, 2)
		if state.probes.moth == null:
			continue
		simulation.submit(MothScanCommand.create(MothRules.Scan.RING))
		ProbeFixture.advance(simulation, 4)
		if state.probes.moth == null:
			assert_int(state.probes.photos.size()).is_equal(1)
			assert_bool(state.probes.ring_scanned.has(WORLD)).is_false()
			return state
	fail("no seed shot the drone down")
	return null


## Saving and loading mid-scan gives the same run as never saving: same losses, battery,
## reports and rack, on a MED world with several rolls.
func test_deterministic_across_save_and_load() -> void:
	for base_seed: int in range(1, 30):
		var straight: GameState = _play(base_seed, false)
		var reloaded: GameState = _play(base_seed, true)
		assert_dict(reloaded.to_dict()).is_equal(straight.to_dict())


func _play(base_seed: int, reload: bool) -> GameState:
	var state: GameState = ProbeFixture.state(WorldDef.Threat.HIGH, base_seed)
	var simulation: Simulation = ProbeFixture.simulation(state)
	ProbeFixture.open(simulation)
	simulation.submit(LaunchMothCommand.new())
	simulation.submit(LaunchCanisterCommand.new())
	simulation.submit(MothScanCommand.create(MothRules.Scan.LOOK_AROUND))
	ProbeFixture.advance(simulation, 3)
	if reload:
		var data: Variant = JSON.parse_string(JSON.stringify(state.to_dict()))
		var data_dict: Dictionary = data
		assert_array(GameState.validate_dict(data_dict)).is_empty()
		var loaded: GameState = GameState.from_dict(data_dict)
		loaded.balance = state.balance
		loaded.galaxy = state.galaxy
		loaded.room_defs = state.room_defs
		loaded.research_defs = state.research_defs
		state = loaded
		simulation = ProbeFixture.simulation(state)
	ProbeFixture.advance(simulation, 2)
	for scan: MothRules.Scan in [MothRules.Scan.SKY, MothRules.Scan.RING, MothRules.Scan.RECALL]:
		if state.probes.moth == null:
			break
		simulation.submit(MothScanCommand.create(scan))
		ProbeFixture.advance(simulation, MothRules.minutes_of(scan))
	ProbeFixture.advance(simulation, 10)
	return state
