class_name CancelBuildCommand
extends Command
## The player cancels a construction site or the dig. The whole site is removed (a corridor
## run with its finished cells) and 75% of its full cost comes back at once; a dig refunds 50%
## of its cost and drops the level. Refunds round down to whole $k. Posts budget_changed when
## applied.
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


## Rejects a dig target with no dig running (&"no_dig"), a room that is not part of a site
## still building (&"not_a_site"), a site with a cell being demolished
## (&"demolition_in_progress": no second refund) and a site whose removal leaves a room or
## site touching no corridor, lift or stairs, counting rooms being demolished as gone
## (&"leaves_room_unconnected").
func validate(state: GameState) -> CommandResult:
	if target == DIG_TARGET:
		if state.base.digging_level() == 0 or state.balance == null:
			return CommandResult.fail(&"no_dig")
		return CommandResult.ok()
	var room: RoomState = state.base.find_room(target)
	if room == null or not _is_building(state.base, room.site_key()):
		return CommandResult.fail(&"not_a_site", String(target))
	var rooms: Array[RoomState] = BaseRules.site_rooms(state.base, room.site_key())
	for part: RoomState in rooms:
		if part.is_demolishing():
			return CommandResult.fail(&"demolition_in_progress")
	if BaseRules.strands_a_room(state.base, state.room_defs, rooms):
		return CommandResult.fail(&"leaves_room_unconnected")
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
		var refund: int = refund_k(state, target)
		for room: RoomState in rooms:
			state.base.remove_room(room.id)
		state.budget.credit(refund)
	state.events.post(&"budget_changed", [state.budget.funds_k])


## What cancelling the site holding room [param room_id] of [param state] refunds, in $k:
## SITE_REFUND_PERCENT of what was paid for the site's rooms, rounded down; 0 for no room.
static func refund_k(state: GameState, room_id: StringName) -> int:
	var room: RoomState = state.base.find_room(room_id)
	if room == null:
		return 0
	var rooms: Array[RoomState] = BaseRules.site_rooms(state.base, room.site_key())
	return BaseRules.paid_k(rooms) * SITE_REFUND_PERCENT / 100


## Returns JSON-safe data: type and target.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "target": String(target)}


## True when a room of the site [param site_key] is still building.
static func _is_building(base: BaseState, site_key: StringName) -> bool:
	for room: RoomState in BaseRules.site_rooms(base, site_key):
		if not room.is_built():
			return true
	return false
