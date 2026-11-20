class_name StartResearchCommand
extends Command
## The player starts a research project at a research building of its discipline (&"" picks
## the first idle one): pays its full cost, spends its pieces and specimens, and makes it that
## bench's active project (ResearchSystem advances it). Posts budget_changed and
## research_started(project id, room id).
## Bible: docs/content/research-and-progression.md section 3

## The command's stable type id.
const TYPE: StringName = &"start_research"

## The project to start.
var project_id: StringName = &""
## The research building, or &"" for the first idle one of the project's discipline.
var room_id: StringName = &""


## Returns a command that starts [param id] at [param room] (&"" picks one).
static func create(id: StringName, room: StringName = &"") -> StartResearchCommand:
	var command := StartResearchCommand.new()
	command.project_id = id
	command.room_id = room
	return command


## Rebuilds a command from its to_dict() data. Fails with &"malformed_command" when
## "project_id" is not a non-empty string or "room_id" is not a string.
static func from_dict(data: Dictionary) -> Result:
	var id: Variant = data.get("project_id")
	var room: Variant = data.get("room_id", "")
	if not SaveFields.is_id(id) or not room is String:
		return Result.fail(&"malformed_command", "start_research needs a project_id")
	return Result.ok(create(StringName(str(id)), StringName(str(room))))


## Returns &"start_research".
func get_type() -> StringName:
	return TYPE


## ResearchRules.can_start().
func validate(state: GameState) -> CommandResult:
	return ResearchRules.can_start(state, project_id, room_id)


## Pays and starts the project at its bench.
func apply(state: GameState) -> void:
	var def: ResearchDef = state.research_defs[project_id]
	var room: StringName = (
		room_id if not room_id.is_empty() else ResearchRules.pick_room(state, def)
	)
	begin(state, project_id, room)


## Pays for [param project] in full, spends its materials, makes it [param room]'s active
## project from zero progress, drops it from any queue and posts budget_changed and
## research_started (also used by the queue).
static func begin(state: GameState, project: StringName, room: StringName) -> void:
	var def: ResearchDef = state.research_defs[project]
	for bench: ResearchBench in state.research.benches.values():
		bench.queue.erase(project)
	state.budget.spend(def.cost_k)
	ResearchSpend.spend(state, def)
	var bench: ResearchBench = state.research.ensure_bench(room)
	bench.active = project
	bench.ticks_done = 0
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"research_started", [project, room])


## Returns JSON-safe data: the type, "project_id" and "room_id".
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "project_id": String(project_id), "room_id": String(room_id)}
