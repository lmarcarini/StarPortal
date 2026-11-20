class_name QueueResearchCommand
extends Command
## The player puts [member project_id] in [member room_id]'s queue at [member position]
## (−1 = at the end; also moves a project already queued there). A bench with nothing
## running starts it at once when it can.
## Bible: docs/content/research-and-progression.md section 3

## The command's stable type id.
const TYPE: StringName = &"queue_research"

## The project.
var project_id: StringName = &""
## The research building whose queue takes it.
var room_id: StringName = &""
## Index in the queue, or −1 for the end.
var position: int = -1


func _init(project: StringName = &"", room: StringName = &"", at: int = -1) -> void:
	project_id = project
	room_id = room
	position = at


## Rebuilds the command from {"type", "project_id", "room_id", "position"}.
static func from_dict(data: Dictionary) -> Result:
	if (
		not SaveFields.is_id(data.get("project_id"))
		or not SaveFields.is_id(data.get("room_id"))
		or not SaveFields.is_int(data.get("position"))
	):
		return Result.fail(&"malformed_command", "queue_research needs project, room, position")
	return Result.ok(
		QueueResearchCommand.new(
			StringName(str(data["project_id"])),
			StringName(str(data["room_id"])),
			SaveFields.read_int(data["position"])
		)
	)


## Returns &"queue_research".
func get_type() -> StringName:
	return TYPE


## ResearchRules.queue_error(), except that a project queued at this bench may be moved.
func validate(state: GameState) -> CommandResult:
	if state.research.room_queuing(project_id) == room_id:
		return CommandResult.ok()
	var error: StringName = ResearchRules.queue_error(state, project_id, room_id)
	return CommandResult.fail(error) if not error.is_empty() else CommandResult.ok()


## Inserts (or moves) the project and starts it at once when the bench is idle and it can.
func apply(state: GameState) -> void:
	var queue: Array[StringName] = state.research.ensure_bench(room_id).queue
	queue.erase(project_id)
	var at: int = queue.size() if position < 0 else mini(position, queue.size())
	queue.insert(at, project_id)
	state.events.post(&"research_queue_changed", [room_id])
	ResearchSystem.start_next(state, room_id)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"project_id": String(project_id),
		"room_id": String(room_id),
		"position": position
	}
