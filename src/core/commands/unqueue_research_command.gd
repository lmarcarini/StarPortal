class_name UnqueueResearchCommand
extends Command
## The player takes [member project_id] out of whichever bench queue holds it.
## Bible: docs/content/research-and-progression.md section 3

## The command's stable type id.
const TYPE: StringName = &"unqueue_research"

## The project.
var project_id: StringName = &""


func _init(project: StringName = &"") -> void:
	project_id = project


## Rebuilds the command from {"type", "project_id"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("project_id")):
		return Result.fail(&"malformed_command", "unqueue_research needs project_id")
	return Result.ok(UnqueueResearchCommand.new(StringName(str(data["project_id"]))))


## Returns &"unqueue_research".
func get_type() -> StringName:
	return TYPE


## Rejects with &"not_queued".
func validate(state: GameState) -> CommandResult:
	if state.research.room_queuing(project_id).is_empty():
		return CommandResult.fail(&"not_queued")
	return CommandResult.ok()


## Removes it.
func apply(state: GameState) -> void:
	var room_id: StringName = state.research.room_queuing(project_id)
	state.research.bench_of(room_id).queue.erase(project_id)
	state.events.post(&"research_queue_changed", [room_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "project_id": String(project_id)}
