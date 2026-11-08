class_name RingActionText
extends RefCounted
## Words of the Ring actions that throw a probe or move a team (RingTeamActions) and of the
## warning before closing the wormhole: what the canister does or when it comes back, where
## Send team takes T-1 or why it is greyed, when the signalled team reaches the Ring, and what
## closing now would lose (the MOTH, the canister and its result). Pure: reads the state.
## Bible: docs/content/m3-beyond-the-ring.md sections 2, 4 and 7


## The note under Throw the sample canister for refusal [param error] (&"" when it can go).
static func canister_note(state: GameState, error: StringName) -> String:
	if state.probes.is_canister_out():
		return _tr(&"GATE_WORMHOLE_CANISTER_OUT").format(
			{"left": GateRoomFormat.duration(state.probes.canister_ticks_left)}
		)
	if error == BudgetState.INSUFFICIENT_FUNDS:
		return _tr(&"GATE_WORMHOLE_CANISTER_FUNDS")
	return _tr(&"GATE_WORMHOLE_CANISTER_NOTE")


## The note under Send team: where T-1 goes, or why it cannot go now ([param error]).
static func team_note(state: GameState, error: StringName) -> String:
	if error == ExpeditionRules.NOT_ENOUGH_TIME:
		return _tr(StringName(ExpeditionRules.NOT_ENOUGH_TIME_TEXT))
	if not error.is_empty():
		return ExpeditionText.refusal(error)
	var plan: ExpeditionState = state.expedition
	return (
		_tr(&"GATE_WORMHOLE_TEAM_NOTE")
		. format(
			{
				"world": AddressBookText.name_of_world(plan.world_id, state),
				"objective": ExpeditionText.objective_name(plan.objective),
				"days": plan.days(),
			}
		)
	)


## The note under Signal T-1: what the Signal does, or, once sent, when T-1 reaches the Ring.
static func signal_note(state: GameState) -> String:
	var sent: int = state.expedition.signal_tick
	if sent < 0:
		return _tr(&"GATE_WORMHOLE_SIGNAL_NOTE")
	var left: int = sent + ExpeditionRescue.SIGNAL_TICKS - state.clock.tick
	return _tr(&"GATE_WORMHOLE_SIGNAL_WAITING").format({"left": GateRoomFormat.duration(left)})


## What closing the wormhole now would lose: "" when nothing, else the warning naming the MOTH,
## the canister and its result, or both.
static func close_warning(state: GameState) -> String:
	var moth: bool = state.probes.is_moth_out()
	var canister: bool = state.probes.is_canister_out()
	if not moth and not canister:
		return ""
	var key: StringName = &"GATE_WORMHOLE_LOSES_BOTH"
	if not canister:
		key = &"GATE_WORMHOLE_LOSES_MOTH"
	elif not moth:
		key = &"GATE_WORMHOLE_LOSES_CANISTER"
	return _tr(&"GATE_WORMHOLE_CLOSE_WARNING").format({"what": _tr(key)})


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
