class_name RoomState
extends RefCounted
## Saved state of one room placed in the base: which RoomDef it is, where it stands, whether it
## is turned, how long until it is built or demolished, which site it is built with and whether
## the player has switched it on.
## Saved shape: {"id", "def_id", "level", "origin": [x, y], "rotated", "build_ticks_left",
## "powered_on", "demolish_ticks_left", "site"}. The last two are optional when loading
## (older saves): missing means 0 and "".
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model

## Saved keys holding whole numbers of at least 0.
const _COUNT_KEYS: Array[String] = ["build_ticks_left"]

## Unique instance id within the base, e.g. &"room_1".
var id: StringName = &""
## Id of the RoomDef this room is.
var def_id: StringName = &""
## Level number, 1 the top underground level (the base has no surface level).
var level: int = 1
## Top-left cell of the footprint.
var origin: Vector2i = Vector2i.ZERO
## True when turned a quarter turn: the def's width and height are swapped.
var rotated: bool = false
## Ticks of building left; 0 means built.
var build_ticks_left: int = 0
## The player's switch for this room (read by the energy layer).
var powered_on: bool = true
## Ticks of demolition left; 0 means not being demolished. A room being demolished is off.
var demolish_ticks_left: int = 0
## Id of the site this room is built with when it shares one with other rooms (a corridor run,
## a lift shaft, stairs); empty when the room is its own site. See site_key().
var site: StringName = &""


## Returns a room of [param def_id] with instance [param room_id] at [param origin] on
## [param level], not turned, built and switched on.
static func create(
	room_id: StringName, def_id: StringName, level: int, origin: Vector2i
) -> RoomState:
	var room := RoomState.new()
	room.id = room_id
	room.def_id = def_id
	room.level = level
	room.origin = origin
	return room


## True when the room is built (no build ticks left).
func is_built() -> bool:
	return build_ticks_left == 0


## True while the room is being demolished.
func is_demolishing() -> bool:
	return demolish_ticks_left > 0


## The id of the construction site the room belongs to: [member site], or its own id.
func site_key() -> StringName:
	return id if site.is_empty() else site


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"def_id": String(def_id),
		"level": level,
		"origin": [origin.x, origin.y],
		"rotated": rotated,
		"build_ticks_left": build_ticks_left,
		"powered_on": powered_on,
		"demolish_ticks_left": demolish_ticks_left,
		"site": String(site),
	}


## Builds a RoomState from saved [param data] (whole floats become ints). Missing or unreadable
## values keep their defaults. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> RoomState:
	var room := RoomState.new()
	room.id = StringName(str(data.get("id", "")))
	room.def_id = StringName(str(data.get("def_id", "")))
	room.level = maxi(1, read_count(data.get("level")))
	room.origin = read_cell(data.get("origin"))
	room.rotated = data.get("rotated") is bool and data["rotated"]
	room.build_ticks_left = read_count(data.get("build_ticks_left"))
	room.powered_on = not (data.get("powered_on") is bool) or data["powered_on"]
	room.demolish_ticks_left = read_count(data.get("demolish_ticks_left"))
	room.site = StringName(str(data.get("site", "")))
	return room


## Returns human-readable errors for saved [param data], empty when it is valid: "id" and
## "def_id" non-empty Strings, "level" a whole number of at least 1, "build_ticks_left" one of
## at least 0,
## "origin" a cell of two whole numbers of at least 0, "rotated" and "powered_on" bools; when
## present, "demolish_ticks_left" a whole number of at least 0 and "site" a String.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["id", "def_id"]:
		if not (data.get(key) is String and not str(data[key]).is_empty()):
			errors.append("'%s' is not a non-empty String" % key)
	for key: String in _COUNT_KEYS:
		if not is_count(data.get(key)):
			errors.append("'%s' is not a whole number of at least 0" % key)
	if not (is_count(data.get("level")) and data["level"] >= 1):
		errors.append("'level' is not a whole number of at least 1")
	if not is_cell(data.get("origin")):
		errors.append("'origin' is not two whole numbers of at least 0")
	for key: String in ["rotated", "powered_on"]:
		if not data.get(key) is bool:
			errors.append("'%s' is not a bool" % key)
	if data.has("demolish_ticks_left") and not is_count(data["demolish_ticks_left"]):
		errors.append("'demolish_ticks_left' is not a whole number of at least 0")
	if data.has("site") and not data["site"] is String:
		errors.append("'site' is not a String")
	return errors


## True for an int, or a whole float, from 0 to [constant JsonLimits.MAX_EXACT_INT].
static func is_count(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


## The whole number in [param value], or 0 when it is not a count.
static func read_count(value: Variant) -> int:
	if not is_count(value):
		return 0
	return type_convert(value, TYPE_INT)


## True for an array of two counts, a saved cell or size.
static func is_cell(value: Variant) -> bool:
	if not value is Array:
		return false
	var pair: Array = value
	return pair.size() == 2 and is_count(pair[0]) and is_count(pair[1])


## The cell saved in [param value], or (0, 0) when it is not a cell.
static func read_cell(value: Variant) -> Vector2i:
	if not is_cell(value):
		return Vector2i.ZERO
	var pair: Array = value
	return Vector2i(read_count(pair[0]), read_count(pair[1]))
