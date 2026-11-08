class_name ChargeAtMaximumCommand
extends Command
## Charge at maximum, the rescue alert's button (docs/content/m3-beyond-the-ring.md section 4):
## sets every Capacitor Bank to its highest rate the supply allows (RescueForecast.max_rates),
## lowering nothing else. Instant and free. Posts power_allocation_changed().
## Bible: docs/content/m3-beyond-the-ring.md section 4

## The command's stable type id.
const TYPE: StringName = &"charge_at_maximum"
## Refusal: no rescue window open.
const NO_RESCUE: StringName = &"no_rescue"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(ChargeAtMaximumCommand.new())


## Returns &"charge_at_maximum".
func get_type() -> StringName:
	return TYPE


## Rejects it outside a rescue window (NO_RESCUE).
func validate(state: GameState) -> CommandResult:
	if state.expedition.mode != ExpeditionState.Mode.MISSING:
		return CommandResult.fail(NO_RESCUE)
	return CommandResult.ok()


## Raises every bank to its maximum rate the spare supply allows.
func apply(state: GameState) -> void:
	var rates: Dictionary[StringName, int] = RescueForecast.max_rates(state)
	for room_id: StringName in rates:
		state.power.charge_rates[room_id] = rates[room_id]
	state.events.post(&"power_allocation_changed", [])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
