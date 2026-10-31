class_name BaseState
extends RefCounted
## Saved state of the base: its levels, the grid every level shares, and the rooms placed on
## them, built or under construction. Rooms point at their RoomDef by id.
## Saved shape: {"grid_size": [w, h], "levels": [LevelState...], "rooms": [RoomState...],
## "next_room_number"}.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Cells of every level: 36 × 20 cells of 3 m (game-design.md#base-building-and-power).
const DEFAULT_GRID_SIZE: Vector2i = Vector2i(36, 20)
## Levels a new campaign starts with, all dug.
const STARTING_LEVELS: int = 3
## The Gate Room's def id; the Ring sits on the deepest starting level.
const GATE_ROOM_DEF: StringName = &"room_gate"
## Placeholder Gate Room origin until the M2 design card sets the starting layout.
const GATE_ROOM_ORIGIN: Vector2i = Vector2i(14, 7)
## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["grid_size", "levels", "rooms", "next_room_number"]

## Number of levels, dug or being dug: the size of [member levels].
var level_count: int:
	get:
		return levels.size()
## Cells of every level (width × height).
var grid_size: Vector2i = DEFAULT_GRID_SIZE
## The underground levels; levels[n - 1] is level n, level 1 the top one. No surface level.
var levels: Array[LevelState] = []
## Every room placed, built or under construction.
var rooms: Array[RoomState] = []
## Number used for the next room's id ("room_<n>"); never reused.
var next_room_number: int = 1


## Returns the campaign's starting base: STARTING_LEVELS dug levels with only the Gate Room,
## built, on the deepest one.
static func starting() -> BaseState:
	var base := BaseState.new()
	for index: int in STARTING_LEVELS:
		base.levels.append(LevelState.new())
	base.add_room(GATE_ROOM_DEF, STARTING_LEVELS, GATE_ROOM_ORIGIN)
	return base


## Places a new built, unturned room of [param def_id] at [param origin] on level
## [param level] (1 the top) with
## the next free id, and returns it. Does not check that it fits (see BaseRules.fits()).
func add_room(def_id: StringName, level: int, origin: Vector2i) -> RoomState:
	var room := RoomState.create(StringName("room_%d" % next_room_number), def_id, level, origin)
	next_room_number += 1
	rooms.append(room)
	return room


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
	return {
		"grid_size": [grid_size.x, grid_size.y],
		"levels": level_data,
		"rooms": room_data,
		"next_room_number": next_room_number,
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
	return base


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "grid_size" two whole numbers of at least 1; "levels" a non-empty array of valid
## levels; "rooms" an array of valid rooms with unique ids, each on an existing level with its
## origin inside the grid; "next_room_number" a whole number of at least 1. Footprints are not
## checked here: that needs the RoomDefs (BaseRules.fits()).
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
	if not errors.is_empty():
		return errors
	var levels: Array = data["levels"]
	if levels.is_empty():
		errors.append("'levels' is empty")
	errors.append_array(_room_place_errors(BaseState.from_dict(data)))
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
	return errors


static func _has_zero(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
