class_name OrderSquadCommand
extends Command
## Orders a squad (M4c-05): Move to a cell, Hold where it is, or Fall back to its post. Works
## while paused; the squad starts walking on the next tick. Also outside an incursion
## (drills). Posts squad_changed.
## Bible: docs/content/m4c-incursions.md section 3

## The command's stable type id.
const TYPE: StringName = &"order_squad"

## The squad: its post's room id.
var squad_id: StringName = &""
## The order.
var order: SquadState.Order = SquadState.Order.HOLD
## Where Move to goes.
var target: Vector3i = Vector3i.ZERO


## A command giving [param squad] the order [param what], to [param to] for a move.
static func create(
	squad: StringName, what: SquadState.Order, to: Vector3i = Vector3i.ZERO
) -> OrderSquadCommand:
	var command := OrderSquadCommand.new()
	command.squad_id = squad
	command.order = what
	command.target = to
	return command


## Rebuilds the command from {"type", "squad", "order", "target"}.
static func from_dict(data: Dictionary) -> Result:
	if not SaveFields.is_id(data.get("squad")):
		return Result.fail(&"malformed_command", "%s needs squad" % TYPE)
	if not StateNames.is_name(SquadState.ORDER_NAMES, data.get("order")):
		return Result.fail(&"malformed_command", "%s needs order" % TYPE)
	if not UnitState.is_pos(data.get("target")):
		return Result.fail(&"malformed_command", "%s needs target" % TYPE)
	var what: SquadState.Order = (
		StateNames.read(SquadState.ORDER_NAMES, data["order"]) as SquadState.Order
	)
	return Result.ok(
		create(SaveFields.read_id(data["squad"]), what, UnitState.read_pos(data["target"]))
	)


## Returns &"order_squad".
func get_type() -> StringName:
	return TYPE


## Rejects an unknown squad (&"no_squad"), one with nobody able to fight (&"squad_down"),
## and a move or fall back with no open path (&"no_path").
func validate(state: GameState) -> CommandResult:
	var squad: SquadState = state.security.squad_of(squad_id)
	if squad == null:
		return CommandResult.fail(&"no_squad")
	if SquadRules.members(state, squad_id).is_empty():
		return CommandResult.fail(&"squad_down")
	if order != SquadState.Order.HOLD:
		var to: Vector3i = _destination(state, squad)
		if BasePaths.walking_distance(state.base, squad.pos, to, state.room_defs) < 0:
			return CommandResult.fail(&"no_path")
	return CommandResult.ok()


## Sets the order and where it goes.
func apply(state: GameState) -> void:
	var squad: SquadState = state.security.squad_of(squad_id)
	squad.order = order
	squad.target = squad.pos if order == SquadState.Order.HOLD else _destination(state, squad)
	state.events.post(&"squad_changed", [squad_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"squad": String(squad_id),
		"order": StateNames.write(SquadState.ORDER_NAMES, order),
		"target": UnitState.write_pos(target),
	}


func _destination(state: GameState, squad: SquadState) -> Vector3i:
	if order != SquadState.Order.FALL_BACK:
		return target
	var room: RoomState = state.base.find_room(squad.post_room)
	return SquadRules.home_of(room) if room != null else squad.pos
