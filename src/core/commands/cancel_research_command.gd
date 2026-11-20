class_name CancelResearchCommand
extends Command
## The player cancels the project running at [member room_id]: half its cost comes back
## (ResearchRules.refund_k(); materials spent are not) and its progress is lost. Posts
## budget_changed and research_cancelled(project id, room id).
## Bible: docs/content/research-and-progression.md section 3

## The command's stable type id.
const TYPE: StringName = &"cancel_research"

## The research building.
var room_id: StringName = &""


func _init(room: StringName = &"") -> void:
	room_id = room


## Rebuilds a command from {"type", "room_id"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("room_id")):
		return Result.fail(&"malformed_command", "cancel_research needs a room_id")
	return Result.ok(CancelResearchCommand.new(StringName(str(data["room_id"]))))


## Returns &"cancel_research".
func get_type() -> StringName:
	return TYPE


## Refuses with &"no_research" when nothing runs at the bench.
func validate(state: GameState) -> CommandResult:
	var bench: ResearchBench = state.research.bench_of(room_id)
	if bench == null or not bench.is_running():
		return CommandResult.fail(&"no_research")
	return CommandResult.ok()


## Refunds half the cost (nothing when the project's def is unknown) and clears the bench.
func apply(state: GameState) -> void:
	var bench: ResearchBench = state.research.bench_of(room_id)
	var project_id: StringName = bench.active
	var def: ResearchDef = state.research_defs.get(project_id)
	if def != null:
		state.budget.credit(ResearchRules.refund_k(def))
	bench.active = &""
	bench.ticks_done = 0
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"research_cancelled", [project_id, room_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "room_id": String(room_id)}
