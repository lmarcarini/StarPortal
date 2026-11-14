class_name DoorState
extends RefCounted
## A blast door on a corridor cell (M4c): OPEN or SEALED, how far intruders have got
## breaching it, and its building. Saved shape: {"cell": [x, y], "level", "mode",
## "breach_ticks", "build_ticks_left", "paid_k"}.
## Bible: docs/content/m4c-incursions.md sections 4 and 9

## OPEN lets everyone through; SEALED blocks everyone until breached.
enum Mode { OPEN, SEALED }

## Saved names of the modes, indexed by Mode value.
const MODE_NAMES: Array[String] = ["open", "sealed"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["cell", "level", "mode", "breach_ticks", "build_ticks_left", "paid_k"]

## Corridor cell.
var cell: Vector2i = Vector2i.ZERO
## Level, from 1.
var level: int = 1
## OPEN or SEALED.
var mode: Mode = Mode.OPEN
## Ticks of breaching done so far.
var breach_ticks: int = 0
## Ticks left to build; 0 once built. A door being built stays OPEN.
var build_ticks_left: int = 0
## What was paid for it, $k.
var paid_k: int = 0


## True once built.
func is_built() -> bool:
	return build_ticks_left == 0


## The door's cell and level as one position.
func pos() -> Vector3i:
	return Vector3i(cell.x, cell.y, level)


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"level": level,
		"mode": StateNames.write(MODE_NAMES, mode),
		"breach_ticks": breach_ticks,
		"build_ticks_left": build_ticks_left,
		"paid_k": paid_k,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> DoorState:
	var door := DoorState.new()
	door.cell = RoomState.read_cell(data.get("cell"))
	door.level = maxi(1, SaveFields.read_int(data.get("level"), 1))
	door.mode = StateNames.read(MODE_NAMES, data.get("mode")) as Mode
	door.breach_ticks = SaveFields.read_int(data.get("breach_ticks"))
	door.build_ticks_left = SaveFields.read_int(data.get("build_ticks_left"))
	door.paid_k = SaveFields.read_int(data.get("paid_k"))
	return door


## Errors of saved [param data].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not RoomState.is_cell(data["cell"]):
		errors.append("'cell' is not two whole numbers of at least 0")
	if not (SaveFields.is_int(data["level"]) and data["level"] >= 1):
		errors.append("'level' is not a whole number of at least 1")
	if not StateNames.is_name(MODE_NAMES, data["mode"]):
		errors.append("'mode' is not open or sealed")
	for key: String in ["breach_ticks", "build_ticks_left", "paid_k"]:
		if not (SaveFields.is_int(data[key]) and data[key] >= 0):
			errors.append("'%s' is not a whole number of at least 0" % key)
	return errors
