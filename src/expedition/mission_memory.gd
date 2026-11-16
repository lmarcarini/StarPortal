class_name MissionMemory
extends RefCounted
## Remembers the plan a team was sent with, per world, so the next mission to that world is
## prefilled (docs/content/interface-rethink.md section 2, The game remembers). Pure static;
## called from SendTeamCommand.apply().
## Bible: docs/content/interface-rethink.md sections 2 and 4 (Gate, Teams)


## Records [param plan]'s objective and team as the last plan for its world.
static func remember(plan: ExpeditionState) -> void:
	if plan.world_id.is_empty():
		return
	var team: Dictionary = {}
	for slot: String in plan.team:
		team[slot] = String(plan.team[slot])
	plan.last_plans[String(plan.world_id)] = {
		"objective": ExpeditionState.OBJECTIVE_NAMES[plan.objective], "team": team
	}
