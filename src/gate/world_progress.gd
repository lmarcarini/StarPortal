class_name WorldProgress
extends RefCounted
## The one place world states and report confidences change, for commands and systems alike
## (the MOTH, the canister, a returning team, a conversation's end): each change only goes up,
## and each real change posts its event. Call only from Command.apply() or SimSystem.tick().
## Events: world_status_changed(world_id, status) and
## world_fact_raised(world_id, fact, confidence).
## Bible: docs/content/m3-beyond-the-ring.md section 3 (a world's state never goes down) and
## section 2 (confidence only goes up)


## Raises [param world_id] to [param status] in [param state] and posts world_status_changed.
## Returns false, changing nothing, when the status is not higher than the current one.
static func raise_status(
	state: GameState, world_id: StringName, status: WorldsState.WorldStatus
) -> bool:
	if world_id.is_empty() or status <= state.worlds.status_of(world_id):
		return false
	state.worlds.statuses[world_id] = status
	state.events.post(&"world_status_changed", [world_id, status as int])
	return true


## Raises [param change]'s fact of its world to its confidence, stamped with the current tick,
## and posts world_fact_raised. Returns false, changing nothing, when it is not higher.
static func raise_fact(state: GameState, change: FactChange) -> bool:
	if change.world_id.is_empty():
		return false
	var report: WorldReport = state.worlds.reports.get(change.world_id)
	if report == null:
		report = WorldReport.new()
	if not report.raise(change.fact, change.confidence, change.source, state.clock.tick):
		return false
	state.worlds.reports[change.world_id] = report
	state.events.post(
		&"world_fact_raised", [change.world_id, change.fact as int, change.confidence as int]
	)
	return true


## One requested rise of a report fact: which world, which fact, to what confidence, and the
## source that raised it.
class FactChange:
	extends RefCounted
	## The world.
	var world_id: StringName
	## The fact.
	var fact: WorldReport.Fact
	## The new confidence; must be above the current one to apply.
	var confidence: WorldReport.Confidence
	## What raised it, e.g. &"moth".
	var source: StringName

	## Returns a change of [param fact_value] of [param world] to [param level] from [param from].
	static func create(
		world: StringName,
		fact_value: WorldReport.Fact,
		level: WorldReport.Confidence,
		from: StringName
	) -> FactChange:
		var change := FactChange.new()
		change.world_id = world
		change.fact = fact_value
		change.confidence = level
		change.source = from
		return change
