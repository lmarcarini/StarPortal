class_name ExpeditionPlanDraft
extends RefCounted
## The plan the player is putting together on the plan sheet of the Expeditions tab
## (docs/content/m3-beyond-the-ring.md section 7), before **Ready team** submits it as a
## [PlanExpeditionCommand]: world, objective, Recover target and team by slot. It is UI state
## only; the choices it offers and the reason it cannot be readied are read from the game state
## through ExpeditionRules.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

## The world chosen; &"" when none.
var world_id: StringName = &""
## The objective chosen.
var objective: ExpeditionState.Objective = ExpeditionState.Objective.SURVEY
## The Recover target; &"" for a Survey.
var target_id: StringName = &""
## The team by slot (ExpeditionState.SLOTS): person ids; a missing slot is empty.
var team: Dictionary[String, StringName] = {}


## The worlds a plan may go to in [param state]: those Probed or beyond, sorted by name.
static func worlds(state: GameState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for world_id: StringName in WorldReportText.known_world_ids(state):
		if state.worlds.has_reached(world_id, WorldsState.WorldStatus.PROBED):
			ids.append(world_id)
	return ids


## The recoverable targets on [param world] in [param state], in the world's order.
static func targets(state: GameState, world: StringName) -> Array[WorldTarget]:
	var found: Array[WorldTarget] = []
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world)
	if facts == null:
		return found
	for target: WorldTarget in facts.targets:
		if state.worlds.targets.is_recoverable(world, target.id):
			found.append(target)
	return found


## The people who may fill [param slot] in [param state]: on base and of a role the slot takes
## (injured people too, so the sheet can say why they cannot go), in roster order.
static func candidates(state: GameState, slot: String) -> Array[PersonState]:
	var roles: Array = ExpeditionRules.slot_roles[slot]
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if not person.is_on_base(state.clock.tick):
			continue
		if roles.is_empty() or person.role in roles:
			found.append(person)
	return found


## Copies the plan of [param state] when it has one (planned or out).
func take_plan(state: GameState) -> void:
	var expedition: ExpeditionState = state.expedition
	if expedition.mode == ExpeditionState.Mode.IDLE:
		return
	world_id = expedition.world_id
	objective = expedition.objective
	target_id = expedition.target_id
	team = expedition.team.duplicate()


## Picks the first world when none is chosen or the chosen one can no longer be planned in
## [param state], and drops a Recover target that is no longer recoverable.
func sync(state: GameState) -> void:
	var ids: Array[StringName] = worlds(state)
	if not world_id in ids:
		choose_world(ids[0] if not ids.is_empty() else &"")
	if objective == ExpeditionState.Objective.RECOVER:
		if not state.worlds.targets.is_recoverable(world_id, target_id):
			choose_objective(ExpeditionState.Objective.SURVEY, &"")


## Chooses [param world]; the objective goes back to Survey.
func choose_world(world: StringName) -> void:
	world_id = world
	choose_objective(ExpeditionState.Objective.SURVEY, &"")


## Chooses [param chosen] ([param target] for a Recover).
func choose_objective(chosen: ExpeditionState.Objective, target: StringName) -> void:
	objective = chosen
	target_id = target if chosen == ExpeditionState.Objective.RECOVER else &""


## Puts [param person_id] in [param slot] (&"" empties it); the person leaves any other slot.
func choose_member(slot: String, person_id: StringName) -> void:
	for other: String in team.keys():
		if team[other] == person_id:
			team.erase(other)
	if person_id.is_empty():
		team.erase(slot)
	else:
		team[slot] = person_id


## Why the draft cannot be readied in [param state], or &"".
func error(state: GameState) -> StringName:
	if world_id.is_empty():
		return ExpeditionRules.NOT_PROBED
	return ExpeditionRules.plan_error(state, _plan(), team)


## True when [param state]'s ready plan is this draft.
func is_ready_in(state: GameState) -> bool:
	var expedition: ExpeditionState = state.expedition
	return (
		expedition.mode == ExpeditionState.Mode.PLANNED
		and expedition.world_id == world_id
		and expedition.objective == objective
		and expedition.target_id == target_id
		and expedition.team == team
	)


## The command that readies this draft.
func to_command() -> PlanExpeditionCommand:
	var members: Dictionary = {}
	for slot: String in team:
		members[slot] = team[slot]
	return PlanExpeditionCommand.create(objective, world_id, target_id, members)


func _plan() -> ExpeditionState:
	var plan := ExpeditionState.new()
	plan.objective = objective
	plan.world_id = world_id
	plan.target_id = target_id
	return plan
