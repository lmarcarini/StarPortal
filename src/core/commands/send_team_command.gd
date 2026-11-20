class_name SendTeamCommand
extends Command
## Send team, a Ring action of a lock on the planned world (docs/content/m3-beyond-the-ring.md
## section 4, Departure): the team goes through at once, so it is never cut off on the way.
## Refused unless the wormhole could stay open MARGIN_TICKS more minutes, on its charge and on
## its time limit, with ExpeditionRules.NOT_ENOUGH_TIME_TEXT as the detail. The team keeps its
## rooms but is out of them until the return (StaffRules.working()). Posts team_sent(world id,
## objective, team names). A long stay (Field camp) doubles the field days.
## Bible: docs/content/m3-beyond-the-ring.md section 4

## The command's stable type id.
const TYPE: StringName = &"send_team"

## A long stay: twice the field days (needs Field camp, E19).
var long_stay: bool = false


func _init(stay_long: bool = false) -> void:
	long_stay = stay_long


## Rebuilds a command from its to_dict() data ("long_stay" optional, false when absent).
static func from_dict(data: Dictionary) -> Result:
	var stay_long: bool = data.get("long_stay", false) == true
	return Result.ok(SendTeamCommand.new(stay_long))


## Returns &"send_team".
func get_type() -> StringName:
	return TYPE


## Rejects what ExpeditionRules.send_error() gives.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ExpeditionRules.send_error(state)
	if long_stay and not ResearchPerks.has(state, ResearchPerks.FIELD_CAMP):
		return CommandResult.fail(&"needs_research", "field_camp")
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
	plan.long_stay = long_stay
	plan.blind = ExpeditionRules.is_blind(state, plan)
	plan.delay_ticks = (
		state.balance.blind_check_in_delay_days * TimeMath.TICKS_PER_DAY if plan.blind else 0
	)
	state.events.post(
		&"team_sent",
		[plan.world_id, plan.objective, ExpeditionSystem.team_names(state), plan.blind]
	)


## Returns JSON-safe data: the type and "long_stay".
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "long_stay": long_stay}
