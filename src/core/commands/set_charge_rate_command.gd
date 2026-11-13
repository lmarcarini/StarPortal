class_name SetChargeRateCommand
extends Command
## The player sets a Capacitor Bank's charge rate: the whole MW of supply allocated to charging
## it, from 0 to the bank's maximum (docs/content/m2-base.md section 3). Instant and free.
## Posts power_allocation_changed() when applied.
## Bible: docs/content/m2-base.md section 3

## The command's stable type id.
const TYPE: StringName = &"set_charge_rate"

## Id of the bank.
var room_id: StringName = &""
## The new charge rate, in whole MW.
var rate_mw: int = 0


## Returns a command that sets bank [param target]'s charge rate to [param mw].
static func create(target: StringName, mw: int) -> SetChargeRateCommand:
	var command := SetChargeRateCommand.new()
	command.room_id = target
	command.rate_mw = mw
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "room_id" is not a String or "rate_mw" not a whole number of at least 0.
static func from_dict(data: Dictionary) -> Result:
	var value: Variant = data.get("room_id")
	if not (value is String and RoomState.is_count(data.get("rate_mw"))):
		return Result.fail(&"malformed_command", "%s needs room_id and rate_mw" % TYPE)
	return Result.ok(create(StringName(str(value)), RoomState.read_count(data["rate_mw"])))


## Returns &"set_charge_rate".
func get_type() -> StringName:
	return TYPE


## Rejects an unknown room (&"unknown_room"), a room that is not a bank (&"not_a_bank"), a
## bank not yet completed or coming down (&"not_built"; a completed bank is settable at once,
## even before PowerSystem has given it a rate), a rate below 0 or above the bank's
## maximum (&"rate_out_of_range"), and a raise that would push allocation over supply
## (&"no_spare_power").
func validate(state: GameState) -> CommandResult:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return CommandResult.fail(&"unknown_room", String(room_id))
	if not PowerRules.is_bank(def):
		return CommandResult.fail(&"not_a_bank")
	if not PowerRules.is_standing(room):
		return CommandResult.fail(&"not_built")
	if rate_mw < 0 or rate_mw > PowerRules.max_charge_mw(state, def):
		return CommandResult.fail(&"rate_out_of_range")
	var raise: int = rate_mw - state.power.charge_rates.get(room_id, 0)
	var spare: float = PowerRules.supply_mw(state) - PowerRules.allocated_mw(state)
	if raise > spare:
		return CommandResult.fail(&"no_spare_power", "needs %d MW; %s MW spare" % [raise, spare])
	return CommandResult.ok()


## Sets the bank's charge rate.
func apply(state: GameState) -> void:
	state.power.charge_rates[room_id] = rate_mw
	state.events.post(&"power_allocation_changed", [])


## Returns JSON-safe data: type, room_id and rate_mw.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "room_id": String(room_id), "rate_mw": rate_mw}
