class_name TeamContactRules
extends RefCounted
## A team talks to the base only through an open gate (docs/content/interface-rethink.md
## section 4): the base hails it while holding a wormhole to its world, a team in trouble dials
## in and calls (an incoming friendly wormhole, no charge), and a team that neither returns
## nor calls by its time plus a grace is overdue. The base knows only what it last heard.
## Pure static rules; mutation only from commands and systems. Bible: as above;
## docs/content/m3-beyond-the-ring.md section 4.

## Orders on a hail.
enum Order { CARRY_ON, COME_HOME, STAY_LONGER, COME_THROUGH, HOLD_ON }

## The incoming_faction id of a team's own call.
const TEAM_CALLER: StringName = &"team"
## Ticks a returning team's wormhole stays open while it walks down the ramp.
const RETURN_TICKS: int = 5
## Grace after a team's return time before it is overdue (12 hours).
const GRACE_TICKS: int = 12 * 60
## The conversation a hail opens (its answers are the hail orders).
const HAIL_CONVERSATION: StringName = &"conv_team_hail"
## The conversation the team's answered call opens (its answers are the call orders).
const CALL_CONVERSATION: StringName = &"conv_team_distress"
## The speaker of team conversations: the team leader (named from the roster by the UI).
const LEADER_SPEAKER: StringName = &"speaker_team_leader"
## Saved names of the orders.
const ORDER_NAMES: Array[String] = [
	"carry_on", "come_home", "stay_longer", "come_through", "hold_on"
]


## True when the base can hail its team: its own wormhole (not a call) is open to the world of
## a team in the field.
static func can_hail_team(state: GameState) -> bool:
	var plan: ExpeditionState = state.expedition
	return (
		state.gate.mode == GateState.RingMode.LOCKED
		and not state.gate.is_incoming_lock()
		and plan.is_out()
		and state.gate.connected_world_id == plan.world_id
	)


## True while the open wormhole is the team's answered call.
static func is_team_call(state: GameState) -> bool:
	return state.gate.is_incoming_lock() and state.gate.incoming_faction == TEAM_CALLER


## Records that the base heard from the team now.
static func hear(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	plan.heard_tick = state.clock.tick
	plan.heard_days = plan.day_results.size()


## The tick the team is due home (departure, delay and its field days); -1 before it leaves.
static func due_tick_of(plan: ExpeditionState) -> int:
	if plan.departed_tick < 0:
		return -1
	return plan.departed_tick + plan.delay_ticks + plan.days() * TimeMath.TICKS_PER_DAY


## Which orders are open now: on a hail, carry on, come home and stay longer; on the
## team's call, come through and hold on; else none.
static func open_orders(state: GameState) -> Array[Order]:
	if is_team_call(state) and state.expedition.mode == ExpeditionState.Mode.MISSING:
		return [Order.COME_THROUGH, Order.HOLD_ON]
	if can_hail_team(state) and state.expedition.mode == ExpeditionState.Mode.AWAY:
		return [Order.CARRY_ON, Order.COME_HOME, Order.STAY_LONGER]
	return []


## Carries out [param order]: come home walks the team through this wormhole, stay longer adds
## a day, come through brings it back now (the mission fails), hold on ends the call (the
## base dials later). Posts team_ordered. Called by OrderTeamCommand and TeamOrderEffect.
static func give_order(state: GameState, order: Order) -> void:
	var plan: ExpeditionState = state.expedition
	match order:
		Order.COME_HOME:
			plan.recalled = true
			plan.coming_home = true
		Order.STAY_LONGER:
			plan.delay_ticks += TimeMath.TICKS_PER_DAY
		Order.COME_THROUGH:
			plan.signal_tick = state.clock.tick
		Order.HOLD_ON:
			RingControl.close(state.gate)
			state.events.post(&"wormhole_closed", [&"call_ended"])
	state.events.post(&"team_ordered", [plan.world_id, ORDER_NAMES[order]])


## The team calls: an incoming friendly wormhole from its world waits for an answer.
static func start_call(state: GameState) -> void:
	var gate: GateState = state.gate
	gate.incoming_faction = TEAM_CALLER
	gate.incoming_conversation = &""
	gate.incoming_until_tick = state.clock.tick + state.balance.incoming_answer_minutes
	state.events.post(&"incoming_wormhole", [TEAM_CALLER])


## The base answers the team's call: the Ring locks to the team's world at no charge; a closed
## Shutter opens for the team's code.
static func answer_call(state: GameState) -> void:
	var plan: ExpeditionState = state.expedition
	RingControl.answer_incoming(state.gate, plan.world_id, state.clock.tick)
	state.gate.shutter = GateState.Shutter.OPEN
	plan.calling = false
	hear(state)
	state.events.post(&"team_called", [plan.world_id])
	ConversationRules.start(state, CALL_CONVERSATION, &"incoming", plan.world_id)


## The team comes home through its own friendly wormhole: the Ring opens as an answered
## incoming lock from [param world] (no charge, no answer awaited; a closed Shutter opens for
## the team's code). Does nothing while the Ring is busy.
static func open_return(state: GameState, world: StringName) -> void:
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.IDLE or gate.has_incoming():
		return
	gate.incoming_faction = TEAM_CALLER
	gate.incoming_conversation = &""
	gate.incoming_until_tick = state.clock.tick
	RingControl.answer_incoming(gate, world, state.clock.tick)
	gate.shutter = GateState.Shutter.OPEN
	state.events.post(&"team_arriving", [world])


## True when a returning team's wormhole has been open long enough and should close.
static func return_done(state: GameState) -> bool:
	return (
		is_team_call(state)
		and not state.expedition.is_out()
		and state.clock.tick - state.gate.lock_started_tick >= RETURN_TICKS
	)


## Nobody answered the team's call: it stops calling and waits.
static func ignore_call(state: GameState) -> void:
	state.gate.clear_incoming()
	state.expedition.calling = false
	state.events.post(&"team_call_missed", [state.expedition.world_id])
