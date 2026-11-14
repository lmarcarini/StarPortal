class_name RepairRoomCommand
extends Command
## Starts repairing a damaged room (M4c-09): pays RepairRules.cost_k(); the ConstructionSystem
## finishes it. Posts budget_changed.
## Bible: docs/content/m4c-incursions.md section 5

## The command's stable type id.
const TYPE: StringName = &"repair_room"

## The room's id.
var room_id: StringName = &""


## A command repairing [param room].
static func create(room: StringName) -> RepairRoomCommand:
	var command := RepairRoomCommand.new()
	command.room_id = room
	return command


## Rebuilds the command from {"type", "room_id"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("room_id")):
		return Result.fail(&"malformed_command", "%s needs room_id" % TYPE)
	return Result.ok(create(SaveFields.read_id(data["room_id"])))


## Returns &"repair_room".
func get_type() -> StringName:
	return TYPE


## Rejects an unknown room (&"unknown_room"), one not damaged (&"not_damaged"), one already
## being repaired (&"repairing") and too little money (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return CommandResult.fail(&"unknown_room")
	if not room.damaged:
		return CommandResult.fail(&"not_damaged")
	if room.repair_ticks_left > 0:
		return CommandResult.fail(&"repairing")
	var funds_error: StringName = state.budget.spend_error(RepairRules.cost_k(def))
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error)
	return CommandResult.ok()


## Pays and starts the repair.
func apply(state: GameState) -> void:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = state.room_defs[room.def_id]
	state.budget.spend(RepairRules.cost_k(def))
	room.repair_ticks_left = RepairRules.ticks(def)
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "room_id": String(room_id)}
