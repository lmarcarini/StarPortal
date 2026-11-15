class_name ExpeditionTripText
extends RefCounted
## Words of the middle and right columns of the Expeditions tab
## (docs/content/m3-beyond-the-ring.md section 7): the timeline of the team away (out, each
## check-in, the return; the next one due), the rescue state of a missing team, the Log lines
## of the trip, the latest check-in with who is injured, and the past: what came back
## (documents) and who did not (members who did not survive, lost teams). Pure: reads the
## state, never changes it.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

## Log reasons that tell who did not come back.
const LOSS_REASONS: Array[String] = ["deceased", "lost", "no_answer"]
const _DOCUMENT_KEYS: Dictionary[String, StringName] = {
	"survey_report": &"EXPEDITION_PAST_SURVEY",
	"object": &"EXPEDITION_PAST_OBJECT",
}


## "T-1  STILLWATER  Survey" for the planned or away team; "BLIND  …" for a blind run.
static func header(state: GameState) -> String:
	var expedition: ExpeditionState = state.expedition
	var tag: String = _tr(&"EXPEDITION_BLIND") + "  " if expedition.blind else ""
	return (
		tag
		+ (
			_tr(&"EXPEDITION_TRIP_HEADER")
			. format(
				{
					"world": AddressBookText.name_of_world(expedition.world_id, state),
					"objective": ExpeditionText.objective_name(expedition.objective),
				}
			)
		)
	)


## The timeline lines of the team away: out, each check-in and the return, each marked done
## or next; a recall and a missed check-in say so. Empty unless a team is out.
static func timeline(state: GameState) -> Array[String]:
	var expedition: ExpeditionState = state.expedition
	var lines: Array[String] = []
	if expedition.mode == ExpeditionState.Mode.MISSING:
		return _missing_lines(state)
	if expedition.mode != ExpeditionState.Mode.AWAY:
		return lines
	lines.append(_tr(&"EXPEDITION_TIMELINE_OUT").format({"date": _date(expedition.departed_tick)}))
	var ticks: Array[int] = expedition.check_in_ticks()
	var next: int = expedition.next_day_end_tick()
	for index: int in ticks.size():
		var key: StringName = &"EXPEDITION_TIMELINE_CHECK_IN"
		if index == ticks.size() - 1:
			key = &"EXPEDITION_TIMELINE_RETURN"
		var mark: StringName = &"EXPEDITION_MARK_DONE" if ticks[index] < next else &""
		if ticks[index] == next:
			mark = &"EXPEDITION_MARK_NEXT"
		var text: String = _tr(key).format({"date": _date(ticks[index])})
		lines.append(text if mark.is_empty() else "%s  %s" % [text, _tr(mark)])
	if expedition.recalled:
		lines.append(_tr(&"EXPEDITION_TIMELINE_RECALLED").format({"date": _date(next)}))
	return lines


## "Next check-in 2 Jan 14:00" (or the return), "" unless a team is away.
static func next_check_in(state: GameState) -> String:
	var expedition: ExpeditionState = state.expedition
	if expedition.mode != ExpeditionState.Mode.AWAY:
		return ""
	var next: int = expedition.next_day_end_tick()
	var key: StringName = &"EXPEDITION_NEXT_CHECK_IN"
	if expedition.recalled or next >= expedition.check_in_ticks()[-1]:
		key = &"EXPEDITION_NEXT_RETURN"
	return _tr(key).format({"date": _date(next)})


## The Log lines of the trip out now ("2 Jan 14:00  T-1 checked in ..."), oldest first.
static func trip_log(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	var expedition: ExpeditionState = state.expedition
	if not expedition.is_out():
		return lines
	for entry: LogEntry in state.operations_log.entries:
		if entry.kind == &"expedition" and entry.tick >= expedition.departed_tick:
			lines.append(_entry_line(state, entry))
	return lines


## The latest check-in Log entry, or null.
static func latest_check_in(state: GameState) -> LogEntry:
	for index: int in range(state.operations_log.entries.size() - 1, -1, -1):
		var entry: LogEntry = state.operations_log.entries[index]
		if entry.kind == &"expedition" and str(entry.args.get("reason", "")) == "checked_in":
			return entry
	return null


## "Injured: Sgt Owen Hale (light, 1 d 4 h)" lines for the team members injured.
static func injured(state: GameState) -> Array[String]:
	var lines: Array[String] = []
	for person_id: StringName in state.expedition.member_ids():
		var person: PersonState = state.staff.find_person(person_id)
		if person == null or not person.is_injured():
			continue
		var key: StringName = &"EXPEDITION_INJURED_LIGHT"
		if person.injury == PersonState.Injury.SERIOUS:
			key = &"EXPEDITION_INJURED_SERIOUS"
		lines.append(
			_tr(key).format(
				{"name": person.name, "time": ResearchText.duration(person.recovery_left)}
			)
		)
	return lines


## The past, newest first: each document a team brought back and each Log line of who did not
## come back.
static func past(state: GameState) -> Array[String]:
	var dated: Array[Array] = []
	for document: Dictionary in state.expedition.documents:
		var key: StringName = _DOCUMENT_KEYS.get(str(document.get("kind", "")), &"")
		if key.is_empty():
			continue
		var world := StringName(str(document.get("world_id", "")))
		var tick: int = type_convert(document.get("tick", 0), TYPE_INT)
		var text: String = _tr(key).format({"world": AddressBookText.name_of_world(world, state)})
		dated.append([tick, "%s  %s" % [_date(tick), text]])
	for entry: LogEntry in state.operations_log.entries:
		if entry.kind == &"expedition" and str(entry.args.get("reason", "")) in LOSS_REASONS:
			dated.append([entry.tick, _entry_line(state, entry)])
	dated.sort_custom(
		func(a: Array, b: Array) -> bool:
			return type_convert(a[0], TYPE_INT) > type_convert(b[0], TYPE_INT)
	)
	var lines: Array[String] = []
	for item: Array in dated:
		lines.append(str(item[1]))
	return lines


## "2 Jan 14:00  <the entry's Log line>".
static func _entry_line(state: GameState, entry: LogEntry) -> String:
	var world: String = AddressBookText.name_of_world(entry.world_id, state)
	return "%s  %s" % [_date(entry.tick), ExpeditionLogText.line(entry.args, world)]


static func _missing_lines(state: GameState) -> Array[String]:
	var expedition: ExpeditionState = state.expedition
	var world: String = AddressBookText.name_of_world(expedition.world_id, state)
	var closes: int = expedition.missed_tick + ExpeditionRescue.WINDOW_DAYS * TimeMath.TICKS_PER_DAY
	var lines: Array[String] = [
		_tr(&"EXPEDITION_TIMELINE_OUT").format({"date": _date(expedition.departed_tick)}),
		_tr(&"EXPEDITION_TIMELINE_MISSED").format({"date": _date(expedition.missed_tick)}),
		_tr(&"EXPEDITION_TIMELINE_RESCUE").format({"world": world}),
		_tr(&"EXPEDITION_TIMELINE_WINDOW").format({"date": _date(closes)}),
	]
	return lines


static func _date(tick: int) -> String:
	return ExpeditionText.date(tick)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
