class_name QueueResearchCommand
extends Command
## The player puts [member project_id] in the research queue at [member position] (−1 = at the
## end; also moves a project already queued there).
## Bible: docs/content/m4-core-systems.md section 7 (4)

## The command's stable type id.
const TYPE: StringName = &"queue_research"

## The project.
var project_id: StringName = &""
## Index in the queue, or −1 for the end.
var position: int = -1


func _init(project: StringName = &"", at: int = -1) -> void:
	project_id = project
	position = at


## Rebuilds the command from {"type", "project_id", "position"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("project_id")) or not SaveFields.is_int(data.get("position")):
		return Result.fail(&"malformed_command", "queue_research needs project_id and position")
	return Result.ok(
		QueueResearchCommand.new(
			StringName(str(data["project_id"])), SaveFields.read_int(data["position"])
		)
	)


## Returns &"queue_research".
func get_type() -> StringName:
	return TYPE


## ResearchRules.queue_error(), except that a queued project may be moved.
func validate(state: GameState) -> CommandResult:
	if state.research.queue.has(project_id):
		return CommandResult.ok()
	var error: StringName = ResearchRules.queue_error(state, project_id)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Inserts (or moves) the project and starts it at once when nothing runs and it can start.
func apply(state: GameState) -> void:
	var queue: Array[StringName] = state.research.queue
	queue.erase(project_id)
	var at: int = queue.size() if position < 0 else mini(position, queue.size())
	queue.insert(at, project_id)
	state.events.post(&"research_queue_changed", [])
	ResearchSystem.start_next(state)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "project_id": String(project_id), "position": position}
