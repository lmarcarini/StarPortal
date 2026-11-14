class_name StartResearchCommand
extends Command
## The player starts a research project: pays its full cost and makes it the active project
## (ResearchSystem advances it). Posts budget_changed and research_started(project id).
## Bible: docs/content/m25-lean-start.md section 3

## The command's stable type id.
const TYPE: StringName = &"start_research"

## The project to start.
var project_id: StringName = &""


## Returns a command that starts [param id].
static func create(id: StringName) -> StartResearchCommand:
	var command := StartResearchCommand.new()
	command.project_id = id
	return command


## Rebuilds a command from its to_dict() data. Fails with &"malformed_command" when
## "project_id" is not a non-empty string.
static func from_dict(data: Dictionary) -> Result:
	var id: Variant = data.get("project_id")
	if not (id is String or id is StringName) or str(id).is_empty():
		return Result.fail(&"malformed_command", "start_research needs a project_id")
	return Result.ok(create(StringName(str(id))))


## Returns &"start_research".
func get_type() -> StringName:
	return TYPE


## ResearchRules.can_start(): refuses with no lab on, while another project runs, with an
## unmet need, too little money, or a locked, done or unknown project.
func validate(state: GameState) -> CommandResult:
	return ResearchRules.can_start(state, project_id)


## Pays in full and makes the project active from zero progress.
func apply(state: GameState) -> void:
	begin(state, project_id)


## Pays for [param project] in full, makes it active from zero progress, drops it from the
## queue and posts budget_changed and research_started (also used by the queue).
static func begin(state: GameState, project: StringName) -> void:
	var def: ResearchDef = state.research_defs[project]
	var project_id: StringName = project
	state.research.queue.erase(project_id)
	state.budget.spend(def.cost_k)
	state.research.active = project_id
	state.research.ticks_done = 0
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"research_started", [project_id])


## Returns JSON-safe data: the type and "project_id".
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "project_id": String(project_id)}
