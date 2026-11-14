class_name BaseState
extends RefCounted
## Saved state of the base: its levels, the grid every level shares, and the rooms placed on
## them, built or under construction. Rooms point at their RoomDef by id.
## Saved shape: {"grid_size": [w, h], "levels": [LevelState...], "rooms": [RoomState...],
## "next_room_number"}.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["grid_size", "levels", "rooms", "next_room_number", "doors"]

## Number of levels, dug or being dug: the size of [member levels].
var level_count: int:
	get:
		return levels.size()
## Cells of every level (width × height); a new game takes it from
## BalanceConfig.base_grid_size (StartingBase.build()).
var grid_size: Vector2i = Vector2i.ONE
## The underground levels; levels[n - 1] is level n, level 1 the top one. No surface level.
var levels: Array[LevelState] = []
## Every room placed, built or under construction.
var rooms: Array[RoomState] = []
## Number used for the next room's id ("room_<n>"); never reused.
var next_room_number: int = 1
## Blast doors on corridor cells (M4c).
var doors: Array[DoorState] = []


## Places a new built, unturned room of [param def_id] at [param origin] on level
## [param level] (1 the top) with
## the next free id, and returns it. Does not check that it fits (see BaseRules.fits()).
func add_room(def_id: StringName, level: int, origin: Vector2i) -> RoomState:
	var room := RoomState.create(StringName("room_%d" % next_room_number), def_id, level, origin)
	next_room_number += 1
	rooms.append(room)
	return room


## Removes the room with id [param room_id], if any.
func remove_room(room_id: StringName) -> void:
	for index: int in rooms.size():
		if rooms[index].id == room_id:
			rooms.remove_at(index)
			return


## Adds a new deepest level that takes [param dig_ticks] (at least 1) to dig, and returns its
## number. Call only from Command.apply().
func start_dig(dig_ticks: int) -> int:
	var level := LevelState.new()
	level.dig_ticks_left = maxi(1, dig_ticks)
	levels.append(level)
	return levels.size()


## The number of the level being dug, or 0 when none is.
func digging_level() -> int:
	for index: int in levels.size():
		if not levels[index].is_dug():
			return index + 1
	return 0


## Drops the level being dug, if it is the deepest (it holds no rooms). Returns true when one
## was dropped.
func cancel_dig() -> bool:
	if levels.is_empty() or levels[-1].is_dug():
		return false
	levels.remove_at(levels.size() - 1)
	return true


## Returns the room with instance id [param room_id], or null.
func find_room(room_id: StringName) -> RoomState:
	for room: RoomState in rooms:
		if room.id == room_id:
			return room
	return null


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var level_data: Array = []
	for level: LevelState in levels:
		level_data.append(level.to_dict())
	var room_data: Array = []
	for room: RoomState in rooms:
		room_data.append(room.to_dict())
	var door_data: Array = []
	for door: DoorState in doors:
		door_data.append(door.to_dict())
	return {
		"grid_size": [grid_size.x, grid_size.y],
		"levels": level_data,
		"rooms": room_data,
		"next_room_number": next_room_number,
		"doors": door_data,
	}


## Builds a BaseState from saved [param data]. Entries that are not objects are skipped.
## Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> BaseState:
	var base := BaseState.new()
	if RoomState.is_cell(data.get("grid_size")):
		base.grid_size = RoomState.read_cell(data["grid_size"])
	for entry: Variant in _array_or_empty(data.get("levels")):
		if entry is Dictionary:
			var level_data: Dictionary = entry
			base.levels.append(LevelState.from_dict(level_data))
	for entry: Variant in _array_or_empty(data.get("rooms")):
		if entry is Dictionary:
			var room_data: Dictionary = entry
			base.rooms.append(RoomState.from_dict(room_data))
	base.next_room_number = maxi(1, RoomState.read_count(data.get("next_room_number")))
	for item: Dictionary in SaveFields.dicts_in(data.get("doors")):
		base.doors.append(DoorState.from_dict(item))
	return base


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "grid_size" two whole numbers of at least 1; "levels" a non-empty array of valid
## levels; "rooms" an array of valid rooms with unique ids, each on an existing level with its
## origin inside the grid, on a dug level, and not both building and being demolished; at most
## one level being dug, and only the deepest; "next_room_number" a whole number of at least 1
## and above every "room_<n>" id's number (so add_room() can never repeat an id); "doors" an
## array of valid blast doors. Footprints are not checked here: that needs the RoomDefs
## (BaseRules.fits()).
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	var grid_ok: bool = RoomState.is_cell(data["grid_size"])
	if not grid_ok or _has_zero(RoomState.read_cell(data["grid_size"])):
		errors.append("'grid_size' is not two whole numbers of at least 1")
	if not (RoomState.is_count(data["next_room_number"]) and data["next_room_number"] >= 1):
		errors.append("'next_room_number' is not a whole number of at least 1")
	errors.append_array(_entry_errors("levels", data["levels"], LevelState.validate_dict))
	errors.append_array(_entry_errors("rooms", data["rooms"], RoomState.validate_dict))
	errors.append_array(_entry_errors("doors", data["doors"], DoorState.validate_dict))
	if not errors.is_empty():
		return errors
	var levels: Array = data["levels"]
	if levels.is_empty():
		errors.append("'levels' is empty")
	var base: BaseState = BaseState.from_dict(data)
	errors.append_array(_room_place_errors(base))
	errors.append_array(_construction_errors(base))
	return errors


## Errors for an undug level that is not the deepest or not the only one, rooms on an undug
## level and rooms both building and coming down.
static func _construction_errors(base: BaseState) -> Array[String]:
	var errors: Array[String] = []
	for index: int in base.levels.size():
		if not base.levels[index].is_dug() and index != base.levels.size() - 1:
			errors.append("level %d: being dug but not the deepest level" % (index + 1))
	for index: int in base.rooms.size():
		var room: RoomState = base.rooms[index]
		var on_level: bool = room.level >= 1 and room.level <= base.level_count
		if on_level and not base.levels[room.level - 1].is_dug():
			errors.append("rooms %d: level %d is still being dug" % [index, room.level])
		if not room.is_built() and room.is_demolishing():
			errors.append("rooms %d: both building and being demolished" % index)
	return errors


## Errors of every entry of [param value] saved under [param key]: not an array, an entry
## that is not an object, or an entry that fails [param check].
static func _entry_errors(key: String, value: Variant, check: Callable) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'%s' is not an array" % key)
		return errors
	var entries: Array = value
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("%s %d is not an object" % [key, index])
			continue
		var found: Array[String] = check.call(entries[index])
		for error: String in found:
			errors.append("%s %d: %s" % [key, index, error])
	return errors


## Errors for duplicate room ids, rooms on a missing level and origins outside the grid.
static func _room_place_errors(base: BaseState) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in base.rooms.size():
		var room: RoomState = base.rooms[index]
		if seen.has(room.id):
			errors.append("rooms %d: duplicate id '%s'" % [index, room.id])
		seen[room.id] = true
		if room.level < 1 or room.level > base.level_count:
			errors.append("rooms %d: level %d does not exist" % [index, room.level])
		if not Rect2i(Vector2i.ZERO, base.grid_size).has_point(room.origin):
			errors.append("rooms %d: origin %s is outside the grid" % [index, room.origin])
		if _room_number(room.id) >= base.next_room_number:
			errors.append("rooms %d: id '%s' is not below 'next_room_number'" % [index, room.id])
	return errors


## The n of a "room_<n>" id, or 0 for any other id.
static func _room_number(room_id: StringName) -> int:
	var text: String = String(room_id)
	if not text.begins_with("room_"):
		return 0
	var digits: String = text.substr(5)
	if not digits.is_valid_int():
		return 0
	return maxi(0, digits.to_int())


static func _has_zero(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
