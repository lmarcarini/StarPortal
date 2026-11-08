class_name SoakProbes
extends RefCounted
## The soak bot's probes: on an open wormhole to a world not yet Probed, or a Probed one whose
## report shows a MED or HIGH threat while money allows, it throws a sample canister while the
## Biohazard is unknown, sends a MOTH from the rack, and orders the first
## scan it may run (Look around, a Close look at each listed target, Ring, Sky, then Recall).
## While the canister or a scan is running it reports itself busy, so the bot keeps the
## wormhole open; runs end recalled, shot down or out of battery (two Close looks), and only
## the wormhole's own limits cut a probe off. Deterministic: no random draws.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes)

## Probe outcomes the soak must see at least once (outcome_key()).
const OUTCOMES: Array[String] = [
	"canister_returned",
	"moth_recalled",
	"moth_lost:shot_down",
	"moth_lost:battery",
	"moth_scan_finished:look_around",
	"moth_scan_finished:close_look",
	"moth_scan_finished:ring",
	"moth_scan_finished:sky",
]
## Funds a Probed world's further runs need, in $k.
const REPROBE_FUNDS_K: int = 3000


## Submits at most one probe command on [param simulation]; true when it did or a probe is
## still busy (the bot must not close the wormhole yet).
static func work(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var world_id: StringName = state.gate.connected_world_id
	if state.probes.is_canister_out():
		return true
	if state.probes.is_moth_out() and state.probes.moth.is_scanning():
		return true
	var report: WorldReport = state.worlds.report_of(world_id)
	if (
		state.worlds.has_reached(world_id, WorldsState.WorldStatus.PROBED)
		and not _probe_again(state, world_id, report)
	):
		return false
	if report.confidence_of(WorldReport.Fact.BIOHAZARD) == WorldReport.Confidence.NONE:
		if _try(simulation, LaunchCanisterCommand.new()):
			return true
	if not state.probes.is_moth_out():
		return _try(simulation, LaunchMothCommand.new())
	for command: MothScanCommand in _scans(state, world_id):
		if _try(simulation, command):
			return true
	return false


## True when a Probed world is worth another run: its report shows a MED or HIGH threat (where
## drones get shot down) and the budget holds REPROBE_FUNDS_K.
static func _probe_again(state: GameState, world_id: StringName, report: WorldReport) -> bool:
	if state.budget.funds_k < REPROBE_FUNDS_K:
		return false
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	var reading: WorldReportRules.ThreatReading = WorldReportRules.threat_reading(
		world_id, facts.threat, report.confidence_of(WorldReport.Fact.THREAT)
	)
	return reading.is_exact() and reading.low >= WorldDef.Threat.MED


static func _scans(state: GameState, world_id: StringName) -> Array[MothScanCommand]:
	var scans: Array[MothScanCommand] = [MothScanCommand.create(MothRules.Scan.LOOK_AROUND)]
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts != null:
		for target: WorldTarget in facts.targets:
			scans.append(MothScanCommand.create(MothRules.Scan.CLOSE_LOOK, target.id))
	scans.append(MothScanCommand.create(MothRules.Scan.RING))
	scans.append(MothScanCommand.create(MothRules.Scan.SKY))
	scans.append(MothScanCommand.create(MothRules.Scan.RECALL))
	return scans


static func _try(simulation: Simulation, command: Command) -> bool:
	if not command.validate(simulation.state).is_ok:
		return false
	return simulation.submit(command).is_ok


## The outcome a domain event [param event_name] with [param args] counts as: the event name,
## with ":" and the reason for moth_lost or the scan name for moth_scan_finished; "" for
## events that are not probe outcomes.
static func outcome_key(event_name: StringName, args: Array) -> String:
	match event_name:
		&"moth_lost":
			return "moth_lost:" + str(args[1])
		&"moth_scan_finished":
			var scan: int = args[0]
			return "moth_scan_finished:" + MothRules.SCAN_NAMES[scan]
		&"canister_returned", &"moth_recalled":
			return String(event_name)
	return ""
