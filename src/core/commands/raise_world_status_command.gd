class_name RaiseWorldStatusCommand
extends Command
## Raises a world's state (Locked, Probed, Surveyed, Contacted) through WorldProgress, posting
## world_status_changed. A state never goes down. The systems that reach a state (the MOTH,
## expeditions, conversations) submit or apply the same rule.
## Bible: docs/content/m3-beyond-the-ring.md section 3 (Worlds)

## The command's stable type id.
const TYPE: StringName = &"raise_world_status"

## The world; must be in the galaxy.
var world_id: StringName
## The new state; above the current one.
var status: WorldsState.WorldStatus


## Returns a command raising [param world] to [param new_status].
static func create(
	world: StringName, new_status: WorldsState.WorldStatus
) -> RaiseWorldStatusCommand:
	var command := RaiseWorldStatusCommand.new()
	command.world_id = world
	command.status = new_status
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "world_id" is not a string or "status" is not a status name.
static func from_dict(data: Dictionary) -> Result:
	var world: Variant = data.get("world_id")
	var status_index: int = WorldsState.STATUS_NAMES.find(str(data.get("status")))
	if not world is String or status_index < 0:
		return Result.fail(&"malformed_command", "raise_world_status needs world_id and status")
	return Result.ok(create(StringName(str(world)), status_index as WorldsState.WorldStatus))


## Returns &"raise_world_status".
func get_type() -> StringName:
	return TYPE


## Rejects a world not in the galaxy (&"unknown_world") and a state not above the current one
## (&"status_not_higher").
func validate(state: GameState) -> CommandResult:
	if state.galaxy == null or state.galaxy.get_world(world_id) == null:
		return CommandResult.fail(&"unknown_world", String(world_id))
	if status <= state.worlds.status_of(world_id):
		return CommandResult.fail(&"status_not_higher", String(world_id))
	return CommandResult.ok()


## Raises the state and posts world_status_changed.
func apply(state: GameState) -> void:
	WorldProgress.raise_status(state, world_id, status)


## Returns JSON-safe data: type, world id and status name.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"world_id": String(world_id),
		"status": WorldsState.STATUS_NAMES[status],
	}
