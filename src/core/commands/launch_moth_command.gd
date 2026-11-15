class_name LaunchMothCommand
extends Command
## While a wormhole is open, the player sends a MOTH from the rack through, with a full battery
## (MothRules.BATTERY_MINUTES); the Gate Room shows its scan screen. Posts
## moth_launched(world id).
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH)

## The command's stable type id.
const TYPE: StringName = &"launch_moth"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(LaunchMothCommand.new())


## Returns &"launch_moth".
func get_type() -> StringName:
	return TYPE


## Rejects a Ring with no open wormhole (&"no_wormhole"), a MOTH already out (&"moth_busy")
## and an empty rack (&"rack_empty").
func validate(state: GameState) -> CommandResult:
	if not MothRules.has_rack(state):
		return CommandResult.fail(&"no_rack")
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"no_wormhole")
	if state.probes.is_moth_out():
		return CommandResult.fail(&"moth_busy")
	if state.probes.rack <= 0:
		return CommandResult.fail(&"rack_empty")
	return CommandResult.ok()


## Takes a drone from the rack and sends it to the connected world.
func apply(state: GameState) -> void:
	state.probes.rack -= 1
	state.probes.moth = MothRun.create(state.gate.connected_world_id)
	state.probes.moth.battery_left = MothRules.battery_minutes(state)
	state.events.post(&"moth_launched", [state.gate.connected_world_id])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
