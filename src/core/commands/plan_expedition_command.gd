class_name PlanExpeditionCommand
extends Command
## The player plans the expedition (docs/content/m3-beyond-the-ring.md section 4): an objective
## (Survey a Probed world, or Recover a recoverable target on it) and a team of four by slot:
## a leader (anyone), a scientist, a soldier and a specialist (medic, engineer, analyst or
## scientist). Replaces any earlier plan; refused while a team is away. Posts
## expedition_planned(world id).
## Bible: docs/content/m3-beyond-the-ring.md section 4 (The team, Objectives)

## The command's stable type id.
const TYPE: StringName = &"plan_expedition"

## The plan to set: objective, world, target; its mode is ignored.
var plan: ExpeditionState = ExpeditionState.new()
## The team by slot: person ids.
var team: Dictionary = {}


## Returns a command planning [param objective] on [param world_id] (of [param target_id] for
## a Recover) with [param members] (slot -> person id).
static func create(
	objective: ExpeditionState.Objective,
	world_id: StringName,
	target_id: StringName,
	members: Dictionary
) -> PlanExpeditionCommand:
	var command := PlanExpeditionCommand.new()
	command.plan.objective = objective
	command.plan.world_id = world_id
	command.plan.target_id = target_id
	command.team = members.duplicate()
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "objective" is not a name, an id is not a string or "team" is not an object.
static func from_dict(data: Dictionary) -> Result:
	var objective: int = ExpeditionState.OBJECTIVE_NAMES.find(str(data.get("objective")))
	var world: Variant = data.get("world_id")
	var target: Variant = data.get("target_id", "")
	var members: Variant = data.get("team")
	if objective < 0 or not world is String or not target is String or not members is Dictionary:
		return Result.fail(&"malformed_command", "plan_expedition needs an objective and a team")
	var command := create(
		objective as ExpeditionState.Objective,
		StringName(str(world)),
		StringName(str(target)),
		members
	)
	return Result.ok(command)


## Returns &"plan_expedition".
func get_type() -> StringName:
	return TYPE


## Rejects what ExpeditionRules.plan_error() gives.
func validate(state: GameState) -> CommandResult:
	var error: StringName = ExpeditionRules.plan_error(state, plan, team)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Sets the plan.
func apply(state: GameState) -> void:
	var target: StringName = (
		plan.target_id if plan.objective == ExpeditionState.Objective.RECOVER else &""
	)
	state.expedition.set_plan(plan.objective, plan.world_id, target, team)
	state.events.post(&"expedition_planned", [plan.world_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	var team_data: Dictionary = {}
	for slot: Variant in team:
		team_data[str(slot)] = str(team[slot])
	return {
		"type": String(TYPE),
		"objective": ExpeditionState.OBJECTIVE_NAMES[plan.objective],
		"world_id": String(plan.world_id),
		"target_id": String(plan.target_id),
		"team": team_data,
	}
