class_name SwitchRoomCommand
extends Command
## The player switches a room on or off (docs/content/m2-base.md section 3). Instant and free.
## Switching on is refused when the room's draw would push allocation over supply; switching a
## plant off is refused when it is the last running one, or when the supply left could not
## cover what is allocated. Posts power_allocation_changed() when applied.
## Bible: docs/content/m2-base.md section 3

## The command's stable type id.
const TYPE: StringName = &"switch_room"

## Id of the room to switch.
var room_id: StringName = &""
## True to switch on, false to switch off.
var on: bool = true


## Returns a command that switches room [param target] on when [param switch_on], else off.
static func create(target: StringName, switch_on: bool) -> SwitchRoomCommand:
	var command := SwitchRoomCommand.new()
	command.room_id = target
	command.on = switch_on
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "room_id" is not a String or "on" not a bool.
static func from_dict(data: Dictionary) -> Result:
	var value: Variant = data.get("room_id")
	if not (value is String and data.get("on") is bool):
		return Result.fail(&"malformed_command", "%s needs room_id and on" % TYPE)
	var switch_on: bool = data["on"]
	return Result.ok(create(StringName(str(value)), switch_on))


## Returns &"switch_room".
func get_type() -> StringName:
	return TYPE


## Rejects an unknown room (&"unknown_room"), a site or a room coming down (&"not_built"), a
## room with no switch: always on, a bank, a lift, stairs or a corridor (&"no_switch"), the
## last running plant (&"last_plant"), and a change that would leave allocation above supply
## (&"no_spare_power"). Switching to the state the room is already in is accepted.
func validate(state: GameState) -> CommandResult:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return CommandResult.fail(&"unknown_room", String(room_id))
	if not PowerRules.is_standing(room):
		return CommandResult.fail(&"not_built")
	if not PowerRules.has_switch(def):
		return CommandResult.fail(&"no_switch")
	if room.powered_on == on:
		return CommandResult.ok()
	return _power_check(state, def)


## The power rules of the switch: the last plant stays on, and the change must fit the spare.
func _power_check(state: GameState, def: RoomDef) -> CommandResult:
	if not on and def.power_output_mw > 0.0 and _running_plants(state) <= 1:
		return CommandResult.fail(&"last_plant")
	var delta: float = def.power_draw_mw - def.power_output_mw
	var spare: float = PowerRules.supply_mw(state) - PowerRules.allocated_mw(state)
	var needed: float = delta if on else -delta
	if needed > spare:
		return CommandResult.fail(&"no_spare_power", "needs %s MW; %s MW spare" % [needed, spare])
	return CommandResult.ok()


## Sets the room's switch.
func apply(state: GameState) -> void:
	state.base.find_room(room_id).powered_on = on
	state.events.post(&"power_allocation_changed", [])


## Returns JSON-safe data: type, room_id and on.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "room_id": String(room_id), "on": on}


## Number of running plants in [param state]'s base.
static func _running_plants(state: GameState) -> int:
	var count: int = 0
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if PowerRules.is_running(room, def) and def.power_output_mw > 0.0:
			count += 1
	return count
