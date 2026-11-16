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
	"field_event", "field_event:injury", "team_distress", "team_rescued"
]
## Most teams the bot sends in a run.
const MAX_SENDS: int = 12

## Teams sent so far (the bot's own count, carried across reloads with the bot).
var sends: int = 0


## Submits at most one expedition command on [param simulation] (a hail with its order counts
## as one); true when it did or a Signal is waiting (the bot must not close the wormhole yet).
## It answers a team's call with Come through or Hold on and hails a team it holds a wormhole
## to (M4.9-11).
func work(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var plan: ExpeditionState = state.expedition
	if _talk(simulation):
		return true
	if plan.mode == ExpeditionState.Mode.MISSING:
		return _rescue(simulation)
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


## Gives Signal T-1 when the base holds a wormhole to the missing team; true when it did or
## a Signal is waiting.
func _rescue(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var plan: ExpeditionState = state.expedition
	if not ExpeditionRescue.is_open_to_team(state):
		return false
	return plan.signal_tick >= 0 or _try(simulation, SignalTeamCommand.new())


## Answers the team's call (Come through or Hold on) or hails a team it holds a wormhole to
## and says Carry on; true when it did.
func _talk(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	var plan: ExpeditionState = state.expedition
	if TeamContactRules.is_team_call(state) and plan.signal_tick < 0:
		var order: TeamContactRules.Order = TeamContactRules.Order.COME_THROUGH
		if plan.missed_tick % 2 == 0:
			order = TeamContactRules.Order.HOLD_ON
		return _try(simulation, OrderTeamCommand.create(order))
	if not TeamContactRules.can_hail_team(state) or plan.heard_tick >= state.gate.lock_started_tick:
		return false
	if not _try(simulation, HailTeamCommand.new()):
		return false
	_try(simulation, OrderTeamCommand.create(TeamContactRules.Order.CARRY_ON))
	return true


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
		&"team_distress", &"team_rescued":
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
