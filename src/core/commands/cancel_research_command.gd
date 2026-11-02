class_name CancelResearchCommand
extends Command
## The player cancels the running research project: half its cost comes back
## (ResearchRules.refund_k()) and its progress is lost. Posts budget_changed and
## research_cancelled(project id).
## Bible: docs/content/m25-lean-start.md section 3

## The command's stable type id.
const TYPE: StringName = &"cancel_research"


## Rebuilds a command from its to_dict() data; it has no arguments, so this never fails.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(CancelResearchCommand.new())


## Returns &"cancel_research".
func get_type() -> StringName:
	return TYPE


## Refuses with &"no_research" when no project runs.
func validate(state: GameState) -> CommandResult:
	if not state.research.is_running():
		return CommandResult.fail(&"no_research")
	return CommandResult.ok()


## Refunds half the cost (nothing when the project's def is unknown) and clears the project.
func apply(state: GameState) -> void:
	var project_id: StringName = state.research.active
	var def: ResearchDef = state.research_defs.get(project_id)
	if def != null:
		state.budget.credit(ResearchRules.refund_k(def))
	state.research.active = &""
	state.research.ticks_done = 0
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"research_cancelled", [project_id])


## Returns JSON-safe data: the type only.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
