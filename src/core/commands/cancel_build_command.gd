class_name CancelBuildCommand
extends Command
## The player cancels a construction site or the dig. A site's unbuilt rooms are removed and
## 75% of what they cost comes back at once (built cells of a corridor run stay); a dig refunds
## 50% of its cost and drops the level. Posts budget_changed when applied.
## Bible: docs/content/m2-base.md section 4

## The command's stable type id.
const TYPE: StringName = &"cancel_build"
## The target that names the running dig instead of a site.
const DIG_TARGET: StringName = &"dig"
## Percent of a site's cost refunded on cancel.
const SITE_REFUND_PERCENT: int = 75
## Percent of a dig's cost refunded on cancel.
const DIG_REFUND_PERCENT: int = 50

## Id of any room of the site, or DIG_TARGET.
var target: StringName = &""


## Returns a command that cancels the site holding room [param room_or_dig], or the dig.
static func create(room_or_dig: StringName) -> CancelBuildCommand:
	var command := CancelBuildCommand.new()
	command.target = room_or_dig
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "target" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var value: Variant = data.get("target")
	if not value is String:
		return Result.fail(&"malformed_command", "%s needs a string target" % TYPE)
	return Result.ok(create(StringName(str(value))))


## Returns &"cancel_build".
func get_type() -> StringName:
	return TYPE


## Rejects a dig target with no dig running (&"no_dig") and a room that is not part of a
## site still building (&"not_a_site").
func validate(state: GameState) -> CommandResult:
	if target == DIG_TARGET:
		if state.base.digging_level() == 0 or state.balance == null:
			return CommandResult.fail(&"no_dig")
		return CommandResult.ok()
	var room: RoomState = state.base.find_room(target)
	if room == null or room.is_built():
		return CommandResult.fail(&"not_a_site", String(target))
	return CommandResult.ok()


## Removes the site's unbuilt rooms, or the dug level, and refunds.
func apply(state: GameState) -> void:
	if target == DIG_TARGET:
		var cost_k: int = DigLevelCommand.cost_k(state, state.base.digging_level())
		state.base.cancel_dig()
		state.budget.credit(cost_k * DIG_REFUND_PERCENT / 100)
	else:
		var rooms: Array[RoomState] = BaseRules.site_rooms(
			state.base, state.base.find_room(target).site_key()
		)
		var cost_k: int = BaseRules.unbuilt_cost_k(state.room_defs, rooms)
		for room: RoomState in rooms:
			if not room.is_built():
				state.base.remove_room(room.id)
		state.budget.credit(cost_k * SITE_REFUND_PERCENT / 100)
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data: type and target.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "target": String(target)}
