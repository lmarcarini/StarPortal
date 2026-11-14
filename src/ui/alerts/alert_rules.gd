class_name AlertRules
extends RefCounted
## Derives the top bar's alerts from the state with no side effects, so they are right after
## a load and nothing new is saved. Standing alerts last while their cause does; event-style
## ones (research_done, team_check_in, artefact_hazard) come from the last day of the Log.
## site_finished is added by the alert list from this session's events (no Log entry exists).
## Bible: docs/content/interface-pass.md section 3 (Alerts)

## How long an event-style alert stays, in ticks: one in-game day.
const EVENT_TICKS: int = TimeMath.TICKS_PER_DAY
## An active request is due when its deadline is this close, in ticks.
const DUE_TICKS: int = 2 * TimeMath.TICKS_PER_DAY


## Every alert of [param state], newest first.
static func current(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	found.append_array(_base_alerts(state))
	found.append_array(_staff_alerts(state))
	found.append_array(_request_alerts(state))
	found.append_array(_artefact_alerts(state))
	found.append_array(_log_alerts(state))
	sort_newest_first(found)
	return found


## Sorts [param entries] newest first, worse first on a tie.
static func sort_newest_first(entries: Array[AlertEntry]) -> void:
	entries.sort_custom(_newer)


## The worst severity in [param entries], or &"" when there are none.
static func worst(entries: Array[AlertEntry]) -> StringName:
	var level: StringName = &""
	for entry: AlertEntry in entries:
		if AlertEntry.rank(entry.severity) > AlertEntry.rank(level):
			level = entry.severity
	return level


static func _base_alerts(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	var now: int = state.clock.tick
	if state.budget.funds_k < 0:
		var red := AlertEntry.create(&"funds_red", AlertEntry.ALARM, ViewSwitcher.COMMAND, now)
		red.args = {"funds": state.budget.funds_k}
		found.append(red)
	if _lab_idle(state):
		found.append(AlertEntry.create(&"lab_idle", AlertEntry.WARN, ViewSwitcher.RESEARCH, now))
	return found


static func _lab_idle(state: GameState) -> bool:
	if state.research.active != &"" or not state.research.queue.is_empty():
		return false
	for room: RoomState in state.base.rooms:
		if room.def_id != &"room_research_lab":
			continue
		var def: RoomDef = state.room_defs.get(room.def_id)
		if PowerRules.is_running(room, def):
			return true
	return false


static func _staff_alerts(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	var now: int = state.clock.tick
	var idle: int = 0
	for person: PersonState in state.staff.people:
		if person.room_id == &"" and person.arrives_tick <= now and not person.lent:
			if not StaffRules.is_on_team(state, person.id):
				idle += 1
	if idle > 0:
		var entry := AlertEntry.create(
			&"staff_unassigned", AlertEntry.WARN, ViewSwitcher.PERSONNEL, now
		)
		entry.args = {"count": idle}
		found.append(entry)
	if StaffRules.beds(state) > 0 and StaffRules.beds_free(state) <= 0:
		found.append(AlertEntry.create(&"beds_full", AlertEntry.INFO, ViewSwitcher.BASE, now))
	if not state.recruitment.candidates.is_empty():
		var waiting := AlertEntry.create(
			&"candidate_waiting", AlertEntry.INFO, ViewSwitcher.PERSONNEL, now
		)
		waiting.args = {"count": state.recruitment.candidates.size()}
		found.append(waiting)
	return found


static func _request_alerts(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	var now: int = state.clock.tick
	for record: RequestRecord in state.requests.items:
		if record.state != RequestRecord.RequestState.ACTIVE or record.deadline_tick < 0:
			continue
		if record.deadline_tick - now > DUE_TICKS:
			continue
		var entry := AlertEntry.create(&"request_due", AlertEntry.WARN, ViewSwitcher.COMMAND, now)
		entry.sub_tab = &"requests"
		entry.target = StringName(str(record.uid))
		entry.args = {"request_id": String(record.request), "ticks": record.deadline_tick - now}
		found.append(entry)
	return found


static func _artefact_alerts(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	for record: ArtefactRecord in state.artefacts.items:
		if record.room_uid != ArtefactRecord.AT_GATE:
			continue
		var entry := AlertEntry.create(
			&"artefact_at_gate", AlertEntry.WARN, ViewSwitcher.GATE_ROOM, record.arrived_tick
		)
		entry.target = StringName(str(record.uid))
		entry.args = {"artefact_id": String(record.artefact)}
		found.append(entry)
	return found


## research_done, team_check_in and artefact_hazard from the last day of the Log.
static func _log_alerts(state: GameState) -> Array[AlertEntry]:
	var found: Array[AlertEntry] = []
	var since: int = state.clock.tick - EVENT_TICKS
	var entries: Array[LogEntry] = state.operations_log.entries
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: LogEntry = entries[index]
		if entry.tick < since:
			break
		var alert: AlertEntry = _from_log(entry)
		if alert != null:
			alert.dismissible = true
			found.append(alert)
	return found


static func _from_log(entry: LogEntry) -> AlertEntry:
	var reason: String = str(entry.args.get("reason", ""))
	if entry.kind == &"research":
		var done := AlertEntry.create(
			&"research_done", AlertEntry.INFO, ViewSwitcher.RESEARCH, entry.tick
		)
		done.target = StringName(str(entry.args.get("project_id", "")))
		done.args = {"project_id": String(done.target)}
		return done
	if entry.kind == &"expedition" and reason == "checked_in":
		var check := AlertEntry.create(
			&"team_check_in", AlertEntry.INFO, ViewSwitcher.EXPEDITIONS, entry.tick
		)
		check.target = entry.world_id
		check.args = {"world_id": String(entry.world_id)}
		return check
	if entry.kind == &"faction" and reason == "hazard":
		var hazard := AlertEntry.create(
			&"artefact_hazard", AlertEntry.ALARM, ViewSwitcher.ARCHIVE, entry.tick
		)
		hazard.sub_tab = &"artefacts"
		hazard.args = {"artefact_id": str(entry.args.get("artefact_id", ""))}
		return hazard
	return null


static func _newer(a: AlertEntry, b: AlertEntry) -> bool:
	if a.tick != b.tick:
		return a.tick > b.tick
	return AlertEntry.rank(a.severity) > AlertEntry.rank(b.severity)
