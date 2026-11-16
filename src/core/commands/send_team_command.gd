class_name SendTeamCommand
extends Command
## Send team, a Ring action of a lock on the planned world (docs/content/m3-beyond-the-ring.md
## section 4, Departure): the team goes through at once, so it is never cut off on the way.
## Refused unless the wormhole could stay open MARGIN_TICKS more minutes, on its charge and on
## its time limit, with ExpeditionRules.NOT_ENOUGH_TIME_TEXT as the detail. The team keeps its
## rooms but is out of them until the return (StaffRules.working()). Posts team_sent(world id,
## objective, team names).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## The command's stable type id.
const TYPE: StringName = &"send_team"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(SendTeamCommand.new())


## Returns &"send_team".
func get_type() -> StringName:
	return TYPE


## Rejects what ExpeditionRules.send_error() gives.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ExpeditionRules.send_error(state)
	if error == ExpeditionRules.NOT_ENOUGH_TIME:
		return CommandResult.fail(error, ExpeditionRules.NOT_ENOUGH_TIME_TEXT)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Sends the team through.
func apply(state: GameState) -> void:
	state.expedition.mode = ExpeditionState.Mode.AWAY
	state.expedition.departed_tick = state.clock.tick
	TeamContactRules.hear(state)
	MissionMemory.remember(state.expedition)
	var plan: ExpeditionState = state.expedition
	plan.blind = ExpeditionRules.is_blind(state, plan)
	plan.delay_ticks = (
		state.balance.blind_check_in_delay_days * TimeMath.TICKS_PER_DAY if plan.blind else 0
	)
	state.events.post(
		&"team_sent",
		[plan.world_id, plan.objective, ExpeditionSystem.team_names(state), plan.blind]
	)


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
