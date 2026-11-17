class_name WireRules
extends RefCounted
## Derives the wire's cards and their action keys from the state and the alerts (pure: no
## side effects, nothing saved). Every old alert kind becomes a card; the wire adds offered
## requests, incoming wormholes and phone calls, low charge and a team's return. Each key
## carries the very command the old screens sent.
## Bible: docs/content/interface-rethink.md sections 3 and 6

## Icon of each card kind.
const ICONS: Dictionary[StringName, StringName] = {
	&"funds_red": &"funds",
	&"lab_idle": &"lab",
	&"research_done": &"lab",
	&"staff_unassigned": &"people",
	&"beds_full": &"base",
	&"candidate_waiting": &"candidate",
	&"request_due": &"clock",
	&"mission_order_failed": &"team",
	&"team_overdue": &"rescue",
	&"incursion": &"threat",
	&"shutdown_countdown": &"confidence",
	&"bankruptcy_countdown": &"funds",
	&"wormhole_open": &"gate",
	&"artefact_at_gate": &"crate",
	&"team_check_in": &"team",
	&"artefact_hazard": &"threat",
	&"site_finished": &"base",
	&"rescue": &"rescue",
	&"request_offered": &"report",
	&"incoming_call": &"gate",
	&"phone_call": &"phone",
	&"charge_low": &"charge",
	&"team_returned": &"team",
}
## Charge below this share of the capacity is low.
const LOW_CHARGE: float = 0.1
## Next projects offered on a lab card.
const PROJECTS: int = 3


## The cards of [param state] from [param entries] (the alert list's), newest first.
static func cards(state: GameState, entries: Array[AlertEntry]) -> Array[WireCardData]:
	var found: Array[WireCardData] = []
	for entry: AlertEntry in entries:
		found.append(from_alert(state, entry))
	found.append_array(extra_cards(state))
	found.sort_custom(func(a: WireCardData, b: WireCardData) -> bool: return a.tick > b.tick)
	return found


## The card of alert [param entry].
static func from_alert(state: GameState, entry: AlertEntry) -> WireCardData:
	var card: WireCardData = _card(entry.kind, entry.tick, entry.severity)
	card.entry = entry
	card.dismissible = entry.dismissible
	card.detail = AlertText.line(entry, state)
	card.actions = WireActions.for_alert(state, entry)
	return card


## Cards the old alerts did not have: offered requests, an incoming wormhole, waiting phone
## calls, low charge and a team's return (from the last day of the Log).
static func extra_cards(state: GameState) -> Array[WireCardData]:
	var found: Array[WireCardData] = []
	for record: RequestRecord in state.requests.items:
		if record.state == RequestRecord.RequestState.OFFERED:
			found.append(_request_card(state, record))
	if state.gate.has_incoming():
		var call: WireCardData = _card(&"incoming_call", state.clock.tick, AlertEntry.WARN)
		call.actions = WireActions.incoming()
		found.append(call)
	if ContactRules.next_pending(state, &"phone") >= 0:
		var phone: WireCardData = _card(&"phone_call", state.clock.tick, AlertEntry.INFO)
		phone.actions = WireActions.phone()
		found.append(phone)
	if _charge_low(state):
		var low: WireCardData = _card(&"charge_low", state.clock.tick, AlertEntry.WARN)
		low.actions = [WireAction.go(&"go_to", &"go_to", ViewSwitcher.BASE, BaseSubTabs.ENERGY)]
		found.append(low)
	found.append_array(_returns(state))
	return found


static func _request_card(state: GameState, record: RequestRecord) -> WireCardData:
	var card: WireCardData = _card(&"request_offered", record.offered_tick, AlertEntry.INFO)
	var def: RequestDef = state.request_defs.get(record.request)
	card.detail = "" if def == null else TranslationServer.translate(def.title_key)
	card.actions = WireActions.request(record.uid)
	return card


static func _returns(state: GameState) -> Array[WireCardData]:
	var found: Array[WireCardData] = []
	var since: int = state.clock.tick - AlertRules.EVENT_TICKS
	var entries: Array[LogEntry] = state.operations_log.entries
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: LogEntry = entries[index]
		if entry.tick < since:
			break
		if DebriefRules.is_return_entry(entry):
			var card: WireCardData = _card(&"team_returned", entry.tick, AlertEntry.INFO)
			card.dismissible = true
			card.actions = [WireAction.step(&"report", &"report", &"report")]
			found.append(card)
	return found


static func _charge_low(state: GameState) -> bool:
	var capacity: float = PowerRules.capacity_mwh(state)
	return capacity > 0.0 and state.power.stored_mwh < capacity * LOW_CHARGE


static func _card(kind: StringName, tick: int, severity: StringName) -> WireCardData:
	var card: WireCardData = WireCardData.new()
	card.kind = kind
	card.tick = tick
	card.severity = severity
	card.icon_id = ICONS.get(kind, &"log")
	card.title_key = StringName("WIRE_" + String(kind).to_upper())
	return card
