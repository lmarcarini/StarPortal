class_name RaiseWorldFactCommand
extends Command
## Raises the confidence of one World Report fact of a world through WorldProgress, stamped with
## its source and the current tick, posting world_fact_raised. Confidence only goes up. The
## probes and teams that reveal a fact submit or apply the same rule.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields)

## The command's stable type id.
const TYPE: StringName = &"raise_world_fact"

## The change: world, fact, confidence and source.
var change: WorldProgress.FactChange


## Returns a command applying [param fact_change].
static func create(fact_change: WorldProgress.FactChange) -> RaiseWorldFactCommand:
	var command := RaiseWorldFactCommand.new()
	command.change = fact_change
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "world_id" or "source" is not a string, "fact" is not a fact name or "confidence" not a
## confidence name.
static func from_dict(data: Dictionary) -> Result:
	var world: Variant = data.get("world_id")
	var source: Variant = data.get("source")
	var fact: int = WorldReport.FACT_NAMES.find(str(data.get("fact")))
	var level: int = WorldReport.CONFIDENCE_NAMES.find(str(data.get("confidence")))
	if not (world is String and source is String) or fact < 0 or level < 0:
		return Result.fail(
			&"malformed_command", "raise_world_fact needs world, fact, level, source"
		)
	var fact_change := WorldProgress.FactChange.create(
		StringName(str(world)),
		fact as WorldReport.Fact,
		level as WorldReport.Confidence,
		StringName(str(source))
	)
	return Result.ok(create(fact_change))


## Returns &"raise_world_fact".
func get_type() -> StringName:
	return TYPE


## Rejects a world not in the galaxy (&"unknown_world"), an empty source (&"empty_source") and a
## confidence not above the current one (&"confidence_not_higher").
func validate(state: GameState) -> CommandResult:
	if state.galaxy == null or state.galaxy.get_world(change.world_id) == null:
		return CommandResult.fail(&"unknown_world", String(change.world_id))
	if change.source.is_empty():
		return CommandResult.fail(&"empty_source")
	var current: WorldReport.Confidence = state.worlds.report_of(change.world_id).confidence_of(
		change.fact
	)
	if change.confidence <= current:
		return CommandResult.fail(&"confidence_not_higher", String(change.world_id))
	return CommandResult.ok()


## Raises the fact and posts world_fact_raised.
func apply(state: GameState) -> void:
	WorldProgress.raise_fact(state, change)


## Returns JSON-safe data: type, world id, fact and confidence names, and source.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"world_id": String(change.world_id),
		"fact": WorldReport.FACT_NAMES[change.fact],
		"confidence": WorldReport.CONFIDENCE_NAMES[change.confidence],
		"source": String(change.source),
	}
