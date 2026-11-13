class_name RequestRules
extends RefCounted
## The request state machine (m4-core-systems.md section 4): accept, decline, and the checks
## that fulfil, fail or lapse a request, each applying its effects exactly once and posting
## request_changed. Called only from commands and RequestSystem.
## Bible: docs/content/m4-core-systems.md section 4


## The open (OFFERED or ACTIVE) instance of [param request], or null.
static func open_instance(state: GameState, request: StringName) -> RequestRecord:
	for record: RequestRecord in state.requests.items:
		if record.request == request and record.is_open():
			return record
	return null


## The instance with [param uid], or null.
static func find(state: GameState, uid: int) -> RequestRecord:
	for record: RequestRecord in state.requests.items:
		if record.uid == uid:
			return record
	return null


## Why [param uid] cannot be accepted or declined now, or &"".
static func offer_error(state: GameState, uid: int) -> StringName:
	var record: RequestRecord = find(state, uid)
	if record == null:
		return &"no_such_request"
	if record.state != RequestRecord.RequestState.OFFERED:
		return &"not_offered"
	return &""


## OFFERED → ACTIVE: sets the deadline (−1 without one) and applies on_accept.
static func accept(state: GameState, uid: int) -> void:
	var record: RequestRecord = find(state, uid)
	var def: RequestDef = state.request_defs.get(record.request)
	record.accepted_tick = state.clock.tick
	record.deadline_tick = -1
	if def != null and def.deadline_days > 0:
		record.deadline_tick = state.clock.tick + def.deadline_days * TimeMath.TICKS_PER_DAY
	_set_state(state, record, RequestRecord.RequestState.ACTIVE)
	if def != null:
		StoryRules.apply_all(state, def.on_accept, def.id)


## OFFERED → DECLINED: applies on_decline.
static func decline(state: GameState, uid: int) -> void:
	_close(state, find(state, uid), RequestRecord.RequestState.DECLINED)


## Checks every open request at the clock's tick: an ACTIVE one whose objective holds is
## fulfilled; one past its deadline fails (or is fulfilled when deadline_succeeds and the
## objective holds); an OFFERED one past its offer lifetime lapses.
static func check_all(state: GameState) -> void:
	for record: RequestRecord in state.requests.items.duplicate():
		if record.is_open():
			check(state, record)


## Checks one open request (see check_all()).
static func check(state: GameState, record: RequestRecord) -> void:
	var def: RequestDef = state.request_defs.get(record.request)
	if def == null:
		return
	var now: int = state.clock.tick
	if record.state == RequestRecord.RequestState.OFFERED:
		if now >= record.offered_tick + def.offer_days * TimeMath.TICKS_PER_DAY:
			_close(state, record, RequestRecord.RequestState.LAPSED)
		return
	var holds: bool = StoryRules.check_all(state, def.objective)
	var past_deadline: bool = record.deadline_tick >= 0 and now >= record.deadline_tick
	if def.deadline_succeeds:
		if past_deadline:
			_close(
				state,
				record,
				RequestRecord.RequestState.FULFILLED if holds else RequestRecord.RequestState.FAILED
			)
		return
	if holds:
		_close(state, record, RequestRecord.RequestState.FULFILLED)
	elif past_deadline:
		_close(state, record, RequestRecord.RequestState.FAILED)


## The effects a request applies on reaching [param closed] (reward, penalty or on_decline).
static func effects_for(def: RequestDef, closed: RequestRecord.RequestState) -> Array[EffectDef]:
	match closed:
		RequestRecord.RequestState.FULFILLED:
			return def.reward
		RequestRecord.RequestState.FAILED:
			return def.penalty
		RequestRecord.RequestState.DECLINED, RequestRecord.RequestState.LAPSED:
			return def.on_decline
	return []


static func _close(
	state: GameState, record: RequestRecord, closed: RequestRecord.RequestState
) -> void:
	record.closed_tick = state.clock.tick
	_set_state(state, record, closed)
	var def: RequestDef = state.request_defs.get(record.request)
	if def != null:
		StoryRules.apply_all(state, effects_for(def, closed), def.id)


static func _set_state(
	state: GameState, record: RequestRecord, to: RequestRecord.RequestState
) -> void:
	record.state = to
	state.events.post(&"request_changed", [record.uid, to as int])
