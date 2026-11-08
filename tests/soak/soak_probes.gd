class_name SoakProbes
extends RefCounted
## The soak bot's probes: on an open wormhole to a world not yet Probed, it throws a sample
## canister while the Biohazard is unknown, sends a MOTH from the rack, and orders the first
## scan it may run (Look around, a Close look at each listed target, Ring, Sky, then Recall).
## The bot closes the wormhole only when this has nothing to do, so a run often ends recalled,
## and sometimes lost (threat, battery). Deterministic: no random draws.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes)


## Submits at most one probe command on [param simulation]; true when it did.
static func work(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var world_id: StringName = state.gate.connected_world_id
	if state.worlds.has_reached(world_id, WorldsState.WorldStatus.PROBED):
		return false
	var report: WorldReport = state.worlds.report_of(world_id)
	if report.confidence_of(WorldReport.Fact.BIOHAZARD) == WorldReport.Confidence.NONE:
		if _try(simulation, LaunchCanisterCommand.new()):
			return true
	if not state.probes.is_moth_out():
		return _try(simulation, LaunchMothCommand.new())
	for command: MothScanCommand in _scans(state, world_id):
		if _try(simulation, command):
			return true
	return false


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
