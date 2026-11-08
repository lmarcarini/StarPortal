class_name LaunchCanisterCommand
extends Command
## While a wormhole is open, the player throws a tethered sample canister through
## ($10k each; canisters never run out). ProbeSystem reels it back after CANISTER_TICKS ticks
## with soil and water, filling the world's Biohazard; closing the wormhole first loses it and
## its result. Posts budget_changed and canister_launched(world id).
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Sample canister)

## The command's stable type id.
const TYPE: StringName = &"launch_canister"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(LaunchCanisterCommand.new())


## Returns &"launch_canister".
func get_type() -> StringName:
	return TYPE


## Rejects a Ring with no open wormhole (&"no_wormhole"), a canister already out
## (&"canister_busy") and too little money (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"no_wormhole")
	if state.probes.is_canister_out():
		return CommandResult.fail(&"canister_busy")
	var error: StringName = state.budget.spend_error(MothRules.CANISTER_COST_K)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Pays for the canister and throws it towards the connected world.
func apply(state: GameState) -> void:
	state.budget.spend(MothRules.CANISTER_COST_K)
	state.probes.canister_world_id = state.gate.connected_world_id
	state.probes.canister_ticks_left = MothRules.CANISTER_TICKS
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"canister_launched", [state.gate.connected_world_id])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
