class_name RemoveInstallationCommand
extends Command
## Removes an installation from a room or door (M4c-18): 75% back while it is being built,
## 50% once built. Posts installation_changed and budget_changed.
## Bible: docs/content/m4c-incursions.md section 6

## The command's stable type id.
const TYPE: StringName = &"remove_installation"

## InstallationDef id.
var def_id: StringName = &""
## The host room's id; &"" for a door.
var room_id: StringName = &""
## The host door's level and cell, when room_id is &"".
var door_level: int = 0
var door_cell: Vector2i = Vector2i.ZERO


## A command removing [param def] from room [param room].
static func create(room: StringName, def: StringName) -> RemoveInstallationCommand:
	var command := RemoveInstallationCommand.new()
	command.room_id = room
	command.def_id = def
	return command


## Rebuilds the command from {"type", "def", "room_id", "door_level", "door_cell"}.
static func from_dict(data: Dictionary) -> Result:
	var host: Result = InstallationHost.read(data)
	if not host.is_ok:
		return host
	var parts: Array = host.value
	var command := RemoveInstallationCommand.new()
	command.def_id = parts[0]
	command.room_id = parts[1]
	command.door_level = parts[2]
	command.door_cell = parts[3]
	return Result.ok(command)


## Returns &"remove_installation".
func get_type() -> StringName:
	return TYPE


## Rejects when the host has no such installation (&"not_installed").
func validate(state: GameState) -> CommandResult:
	var items: Array[InstallationState] = InstallationHost.list_of(
		state, room_id, door_level, door_cell
	)
	if InstallationRules.find(items, def_id) == null:
		return CommandResult.fail(&"not_installed")
	return CommandResult.ok()


## Removes it and refunds.
func apply(state: GameState) -> void:
	var items: Array[InstallationState] = InstallationHost.list_of(
		state, room_id, door_level, door_cell
	)
	var item: InstallationState = InstallationRules.find(items, def_id)
	items.erase(item)
	InstallationState.revision += 1
	state.budget.credit(InstallationRules.refund_k(item))
	var key: StringName = InstallationHost.items_of(state, room_id, door_level, door_cell, null)
	state.events.post(&"installation_changed", [key])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return InstallationHost.write(TYPE, def_id, room_id, door_level, door_cell)
