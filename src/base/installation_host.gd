class_name InstallationHost
extends RefCounted
## The host (a room or a blast door) of the installation commands: reading and writing it, and
## adding an installation to it.
## Bible: docs/content/m4c-incursions.md section 6


## Reads {"def", "room_id", "door_level", "door_cell"} as [def, room_id, level, cell].
static func read(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("def")) or not data.get("room_id") is String:
		return Result.fail(&"malformed_command", "installation commands need def and room_id")
	if not (SaveFields.is_int(data.get("door_level")) and RoomState.is_cell(data.get("door_cell"))):
		return Result.fail(
			&"malformed_command", "installation commands need door_level and door_cell"
		)
	return (
		Result
		. ok(
			[
				SaveFields.read_id(data["def"]),
				StringName(str(data["room_id"])),
				SaveFields.read_int(data["door_level"]),
				RoomState.read_cell(data["door_cell"]),
			]
		)
	)


## JSON-safe data of a command of [param type] with its host.
static func write(
	type: StringName, def_id: StringName, room_id: StringName, level: int, cell: Vector2i
) -> Dictionary:
	return {
		"type": String(type),
		"def": String(def_id),
		"room_id": String(room_id),
		"door_level": level,
		"door_cell": [cell.x, cell.y],
	}


## The installations of the host (room [param room_id], else the door at [param cell] on
## [param level]) of [param state], with [param item] appended when given; returns the key
## installation_changed reports for it.
static func items_of(
	state: GameState, room_id: StringName, level: int, cell: Vector2i, item: InstallationState
) -> StringName:
	if not room_id.is_empty():
		var room: RoomState = state.base.find_room(room_id)
		if room != null and item != null:
			room.installations.append(item)
		return room_id
	var door: DoorState = DoorRules.find(state.base, level, cell)
	if door != null and item != null:
		door.installations.append(item)
	return InstallationRules.door_key(door) if door != null else &""


## The installations list of the host, or an empty one.
static func list_of(
	state: GameState, room_id: StringName, level: int, cell: Vector2i
) -> Array[InstallationState]:
	if not room_id.is_empty():
		var room: RoomState = state.base.find_room(room_id)
		return room.installations if room != null else []
	var door: DoorState = DoorRules.find(state.base, level, cell)
	return door.installations if door != null else []
