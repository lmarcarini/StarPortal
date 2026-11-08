class_name SoakExpeditions
extends RefCounted
## The soak bot's expeditions, kept cheap: on an open wormhole to a Probed world whose true
## threat is MED or HIGH (where the worst field events can happen), with no plan, it plans a
## Survey (a lent soldier leads, the first fit scientist, the other lent soldier, the first fit
## engineer as specialist) and sends the team, at most MAX_SENDS times a run. While a team is
## missing it dials the team's world (rescue_address()) and, on a lock there, sends Signal T-1
## and keeps the wormhole open until the team is through. Deterministic: no random draws.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (Risk model; Missed check-in and rescue)

## Expedition outcomes the soak must see at least once (outcome_key()).
const OUTCOMES: Array[String] = [
	"field_event", "field_event:injury", "check_in_missed", "team_rescued"
]
## Most teams the bot sends in a run.
const MAX_SENDS: int = 12

## Teams sent so far (the bot's own count, carried across reloads with the bot).
var sends: int = 0


## Submits at most one expedition command on [param simulation]; true when it did or a
## Signal is waiting (the bot must not close the wormhole yet).
func work(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var plan: ExpeditionState = state.expedition
	if plan.mode == ExpeditionState.Mode.MISSING:
		if not ExpeditionRescue.is_open_to_team(state):
			return false
		return plan.signal_tick >= 0 or _try(simulation, SignalTeamCommand.new())
	if plan.mode == ExpeditionState.Mode.PLANNED and _try(simulation, SendTeamCommand.new()):
		sends += 1
		return true
	if plan.mode != ExpeditionState.Mode.IDLE or sends >= MAX_SENDS or not _worth_sending(state):
		return false
	var team: Dictionary = _team(state)
	if team.is_empty():
		return false
	var command := PlanExpeditionCommand.create(
		ExpeditionState.Objective.SURVEY, state.gate.connected_world_id, &"", team
	)
	return _try(simulation, command)


## The true address of the missing team's world, or null when no team is missing.
static func rescue_address(state: GameState) -> GateAddress:
	if state.expedition.mode != ExpeditionState.Mode.MISSING:
		return null
	return state.galaxy.address_of(state.expedition.world_id, state.galaxy.home().origin_glyph)


## The outcome a domain event counts as (OUTCOMES), or "" for other events.
static func outcome_key(event_name: StringName, args: Array) -> String:
	match event_name:
		ExpeditionFieldDay.EVENT:
			return "field_event:injury" if str(args[2]) in ["light", "serious"] else "field_event"
		&"check_in_missed", &"team_rescued":
			return String(event_name)
	return ""


static func _worth_sending(state: GameState) -> bool:
	var world_id: StringName = state.gate.connected_world_id
	if not ExpeditionUnlock.is_unlocked(state):
		return false
	if not state.worlds.has_reached(world_id, WorldsState.WorldStatus.PROBED):
		return false
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	return facts != null and facts.threat >= WorldDef.Threat.MED


static func _team(state: GameState) -> Dictionary:
	var soldiers: Array[PersonState] = _fit(state, StartingStaff.SOLDIER)
	var scientists: Array[PersonState] = _fit(state, StartingStaff.SCIENTIST)
	var engineers: Array[PersonState] = _fit(state, StartingStaff.ENGINEER)
	if soldiers.size() < 2 or scientists.is_empty() or engineers.is_empty():
		return {}
	return {
		"leader": soldiers[1].id,
		"scientist": scientists[0].id,
		"soldier": soldiers[0].id,
		"specialist": engineers[0].id,
	}


static func _fit(state: GameState, role: StringName) -> Array[PersonState]:
	return state.staff.people.filter(
		func(p: PersonState) -> bool:
			return p.role == role and not p.is_injured() and p.is_on_base(state.clock.tick)
	)


static func _try(simulation: Simulation, command: Command) -> bool:
	if not command.validate(simulation.state).is_ok:
		return false
	return simulation.submit(command).is_ok
