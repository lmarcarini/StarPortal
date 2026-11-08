class_name SignalTeamCommand
extends Command
## Signal T-1, a Ring action of a lock on the missing team's world during the rescue window
## (docs/content/m3-beyond-the-ring.md section 4, Missed check-in and rescue): the team
## reaches the Ring ExpeditionRescue.SIGNAL_TICKS later and comes through; closing the
## wormhole before fails the Signal, and the player can try again within the window. Posts
## rescue_signal_sent(world id).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## The command's stable type id.
const TYPE: StringName = &"signal_team"
## Refusals: no rescue window open, no wormhole open to the world, a Signal already waiting.
const NO_RESCUE: StringName = &"no_rescue"
const SIGNAL_WAITING: StringName = &"signal_waiting"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(SignalTeamCommand.new())


## Returns &"signal_team".
func get_type() -> StringName:
	return TYPE


## Rejects no open rescue window (NO_RESCUE), no wormhole open to the team's world
## (ExpeditionRules.NO_WORMHOLE) and a Signal already waiting (SIGNAL_WAITING).
func validate(state: GameState) -> CommandResult:
	if state.expedition.mode != ExpeditionState.Mode.MISSING:
		return CommandResult.fail(NO_RESCUE)
	if not ExpeditionRescue.is_open_to_team(state):
		return CommandResult.fail(ExpeditionRules.NO_WORMHOLE)
	if state.expedition.signal_tick >= 0:
		return CommandResult.fail(SIGNAL_WAITING)
	return CommandResult.ok()


## Sends the Signal now.
func apply(state: GameState) -> void:
	state.expedition.signal_tick = state.clock.tick
	state.events.post(&"rescue_signal_sent", [state.expedition.world_id])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
