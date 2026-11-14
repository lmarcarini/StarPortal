class_name InstallCommand
extends Command
## Fits an installation to a room or a blast door (M4c-18): pays its price and starts it as a
## small site. Posts installation_changed and budget_changed.
## Bible: docs/content/m4c-incursions.md section 6

## The command's stable type id.
const TYPE: StringName = &"install"

## InstallationDef id.
var def_id: StringName = &""
## The host room's id; &"" for a door.
var room_id: StringName = &""
## The host door's level and cell, when room_id is &"".
var door_level: int = 0
var door_cell: Vector2i = Vector2i.ZERO


## A command fitting [param def] to room [param room].
static func create(room: StringName, def: StringName) -> InstallCommand:
	var command := InstallCommand.new()
	command.room_id = room
	command.def_id = def
	return command


## A command fitting [param def] to the door at [param cell] on [param level].
static func create_door(level: int, cell: Vector2i, def: StringName) -> InstallCommand:
	var command := InstallCommand.new()
	command.door_level = level
	command.door_cell = cell
	command.def_id = def
	return command


## Rebuilds the command from {"type", "def", "room_id", "door_level", "door_cell"}.
static func from_dict(data: Dictionary) -> Result:
	var host: Result = InstallationHost.read(data)
	if not host.is_ok:
		return host
	var parts: Array = host.value
	var command := InstallCommand.new()
	command.def_id = parts[0]
	command.room_id = parts[1]
	command.door_level = parts[2]
	command.door_cell = parts[3]
	return Result.ok(command)


## Returns &"install".
func get_type() -> StringName:
	return TYPE


## InstallationRules.can_install() on the host; a missing room or door is &"wrong_host".
func validate(state: GameState) -> CommandResult:
	var room: RoomState = state.base.find_room(room_id) if not room_id.is_empty() else null
	var door: DoorState = (
		DoorRules.find(state.base, door_level, door_cell) if room_id.is_empty() else null
	)
	if room == null and door == null:
		return CommandResult.fail(&"wrong_host")
	return InstallationRules.can_install(state, def_id, room, door)


## Pays and starts it.
func apply(state: GameState) -> void:
	var def: InstallationDef = state.installation_defs[def_id]
	var item: InstallationState = InstallationRules.create(def)
	state.budget.spend(def.cost_k)
	var key: StringName = InstallationHost.items_of(state, room_id, door_level, door_cell, item)
	state.events.post(&"installation_changed", [key])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return InstallationHost.write(TYPE, def_id, room_id, door_level, door_cell)
