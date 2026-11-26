class_name OpenResearchCommand
extends Command
## The player opens [member project_id] in the Lab: a revealed project not yet opened is
## recorded as opened, so its NEW lamp goes out (research_opened). Opening one already opened
## is a no-op that still succeeds.
## Bible: docs/content/research-and-progression.md section 7

## The command's stable type id.
const TYPE: StringName = &"open_research"

## The project.
var project_id: StringName = &""


func _init(project: StringName = &"") -> void:
	project_id = project


## Rebuilds the command from {"type", "project_id"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("project_id")):
		return Result.fail(&"malformed_command", "open_research needs project_id")
	return Result.ok(OpenResearchCommand.new(StringName(str(data["project_id"]))))


## Returns &"open_research".
func get_type() -> StringName:
	return TYPE


## Rejects with &"unknown_project" when the project does not exist or is not visible.
func validate(state: GameState) -> CommandResult:
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null or not ResearchRules.visible(state, def):
		return CommandResult.fail(&"unknown_project", String(project_id))
	return CommandResult.ok()


## Records it as opened (once).
func apply(state: GameState) -> void:
	if state.research.opened.has(project_id):
		return
	state.research.opened.append(project_id)
	state.events.post(&"research_opened", [project_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "project_id": String(project_id)}
