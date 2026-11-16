class_name HailTeamCommand
extends Command
## The base hails its team through the wormhole it holds open to the team's world: the base
## hears where the team is and how it is (team_hailed), and may then give an order
## (OrderTeamCommand). Costs nothing beyond holding the wormhole open.
## Bible: docs/content/interface-rethink.md section 4 (A team can only talk through an open gate)

## The command's stable type id.
const TYPE: StringName = &"hail_team"

## Rebuilds the command; it has no fields.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(HailTeamCommand.new())


## Returns &"hail_team".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_team_there" unless a wormhole of the base is open to the team's world.
func validate(state: GameState) -> CommandResult:
	if not TeamContactRules.can_hail_team(state):
		return CommandResult.fail(&"no_team_there")
	return CommandResult.ok()


## Hears the team: posts team_hailed(world, days done, days, light, serious).
func apply(state: GameState) -> void:
	TeamContactRules.hear(state)
	var plan: ExpeditionState = state.expedition
	var hurt: Vector2i = ExpeditionSystem.injuries(state)
	state.events.post(&"team_hailed", [plan.world_id, plan.heard_days, plan.days(), hurt.x, hurt.y])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
