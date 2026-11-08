class_name ProbeSystem
extends SimSystem
## Moves the probes each tick, after GateSystem and DocumentSystem: replacement MOTHs arrive in
## the rack; the sample canister is reeled back with the world's Biohazard after
## CANISTER_TICKS ticks, or lost when the wormhole to its world closes first; the MOTH's
## running scan drains its battery a minute a tick and, when done, rolls a seeded loss by the
## world's true threat (doubled for a Close look) before giving its result (MothScanEffects).
## [br][br]
## A run ends when the drone is recalled (back in the rack), shot down (finished scans kept,
## threat confidence one step up, to FAIR at most), left without battery for a recall, or cut
## off by the wormhole closing. Every end makes the world PROBED; every loss orders a
## replacement automatically ($150k, charged even into debt like upkeep, arriving in a day).
## Events: canister_returned(world id, biohazard), canister_lost(world id),
## moth_scan_finished(scan, target id), moth_recalled(world id), moth_lost(world id, reason:
## &"shot_down", &"battery" or &"wormhole_closed"), moth_delivered(rack count), budget_changed.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes; losses)

## Id of the system and of its random stream.
const ID: StringName = &"probes"
## Source id of the canister's report fact.
const CANISTER_SOURCE: StringName = &"canister"


## Returns &"probes".
func get_id() -> StringName:
	return ID


## Delivers due replacements, then moves the canister and the MOTH.
func tick(state: GameState) -> void:
	_deliver_reorders(state)
	_move_canister(state)
	_move_moth(state)


func _deliver_reorders(state: GameState) -> void:
	var probes: ProbesState = state.probes
	while not probes.reorders.is_empty() and probes.reorders[0] <= state.clock.tick:
		probes.reorders.pop_front()
		probes.rack += 1
		state.events.post(&"moth_delivered", [probes.rack])


func _move_canister(state: GameState) -> void:
	var probes: ProbesState = state.probes
	if not probes.is_canister_out():
		return
	var world_id: StringName = probes.canister_world_id
	if not _is_open_to(state, world_id):
		probes.clear_canister()
		state.events.post(&"canister_lost", [world_id])
		return
	probes.canister_ticks_left -= 1
	if probes.canister_ticks_left > 0:
		return
	probes.clear_canister()
	WorldProgress.raise_fact(
		state,
		WorldProgress.FactChange.create(
			world_id, WorldReport.Fact.BIOHAZARD, WorldReport.Confidence.FAIR, CANISTER_SOURCE
		)
	)
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	var biohazard: int = facts.biohazard if facts != null else WorldDef.Biohazard.UNKNOWN
	state.events.post(&"canister_returned", [world_id, biohazard])


func _move_moth(state: GameState) -> void:
	var run: MothRun = state.probes.moth
	if run == null:
		return
	if not _is_open_to(state, run.world_id):
		_end_run(state, &"wormhole_closed")
		return
	if not run.is_scanning():
		return
	run.battery_left -= 1
	run.scan_ticks_left -= 1
	if run.scan_ticks_left == 0:
		_finish_scan(state, run)


func _finish_scan(state: GameState, run: MothRun) -> void:
	var scan := run.scan as MothRules.Scan
	var target_id: StringName = run.target_id
	run.scan = -1
	run.target_id = &""
	if _rolls_loss(state, run.world_id, scan):
		_end_run(state, &"shot_down")
		return
	MothScanEffects.apply(state, run.world_id, scan, target_id)
	state.events.post(&"moth_scan_finished", [scan as int, target_id])
	if scan == MothRules.Scan.RECALL:
		state.probes.rack += 1
		_end_run(state, &"")
		return
	run.done.append(MothRun.scan_key(scan, target_id))
	if not MothRules.can_recall(run.battery_left):
		_end_run(state, &"battery")


## Ends the run: recalled when [param loss] is &"", else lost for that reason.
func _end_run(state: GameState, loss: StringName) -> void:
	var world_id: StringName = state.probes.moth.world_id
	state.probes.moth = null
	WorldProgress.raise_status(state, world_id, WorldsState.WorldStatus.PROBED)
	if loss.is_empty():
		state.events.post(&"moth_recalled", [world_id])
		return
	if loss == &"shot_down":
		var current: WorldReport.Confidence = state.worlds.report_of(world_id).confidence_of(
			WorldReport.Fact.THREAT
		)
		WorldProgress.raise_fact(
			state,
			WorldProgress.FactChange.create(
				world_id,
				WorldReport.Fact.THREAT,
				MothRules.confidence_after_loss(current),
				MothScanEffects.SOURCE
			)
		)
	state.budget.funds_k -= MothRules.REORDER_COST_K
	state.probes.reorders.append(state.clock.tick + MothRules.REORDER_TICKS)
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"moth_lost", [world_id, loss])


func _rolls_loss(state: GameState, world_id: StringName, scan: MothRules.Scan) -> bool:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	var threat: WorldDef.Threat = facts.threat if facts != null else WorldDef.Threat.LOW
	var percent: int = MothRules.loss_percent(threat, scan)
	if percent <= 0:
		return false
	return state.random.stream(ID).randi_range(0, 99) < percent


func _is_open_to(state: GameState, world_id: StringName) -> bool:
	return (
		state.gate.mode == GateState.RingMode.LOCKED and state.gate.connected_world_id == world_id
	)
