class_name LogRules
extends RefCounted
## Pure rules of the operations log: which entries a domain event writes. They read the state
## only to name the world of a close (the Ring's last lock) and never change it.
## Bible: game-design.md#core-loop (Archive: the operations log)


## Returns the entries domain event [param event_name] with [param args] writes at
## [param tick], in order; empty for events the log ignores. A dial writes a "dial" entry
## (address key and outcome key; the world only on a lock, so a failure never names it), and a
## lock also writes a "lock" entry. A close names the world of the Ring's last lock in
## [param state]; horizon records and console reads name the world given in the event.
static func entries_for(
	event_name: StringName, args: Array, state: GameState, tick: int
) -> Array[LogEntry]:
	match event_name:
		&"dial_resolved":
			return _dial_entries(args, state, tick)
		&"wormhole_closed":
			return [
				LogEntry.create(tick, &"close", _last_lock_world(state), {"reason": _text(args)})
			]
		&"document_received":
			return [LogEntry.create(tick, &"document", &"", {"document_id": _text(args)})]
		&"console_read":
			return [LogEntry.create(tick, &"console", StringName(_text(args)))]
		&"horizon_record_taken":
			return [LogEntry.create(tick, &"horizon", StringName(_text(args)))]
		&"capacitors_installed":
			return [_power_entry(args, state, tick)]
		&"charging_lowered", &"room_finished_off", &"supply_dropped":
			return _finished_room_entries(event_name, args, state, tick)
		&"faction_met":
			return [LogEntry.create(tick, &"faction", &"", {"faction_id": _text(args)})]
		&"research_done":
			return [LogEntry.create(tick, &"research", &"", {"project_id": _text(args)})]
		&"staff_changed":
			return _staff_entries(args, tick)
		&"reports_filed", &"committee_commendation", &"committee_warning":
			return [_committee_entry(event_name, args, state, tick)]
		&"staff_arrived", ExpeditionUnlock.LENT_EVENT:
			return _arrival_entries(args, state, tick, event_name != &"staff_arrived")
		&"team_sent", &"team_returned":
			return [_trip_entry(event_name, args, tick)]
		ExpeditionSystem.PROLOGUE_EVENT:
			return [
				LogEntry.create(
					tick, &"expedition", StringName(_text(args)), {"reason": "prologue"}
				)
			]
		ExpeditionFieldDay.EVENT:
			return [_field_event_entry(args, tick)]
		&"team_checked_in", &"check_in_missed", &"member_deceased", &"team_lost", &"team_rescued":
			return _expedition_entries(event_name, args, tick)
	return []


## The "expedition" entry of a departure ("reason" "departed") or a normal return ("returned",
## with "success"): the team's world, "objective" (its saved name) and "team" (names in slot
## order, joined by ", "; log arguments hold no string lists), so past trips can be grouped
## (m3-beyond-the-ring.md section 4).
static func _trip_entry(event_name: StringName, args: Array, tick: int) -> LogEntry:
	var saved: int = type_convert(args[1], TYPE_INT)
	var objective: int = clampi(saved, 0, ExpeditionState.OBJECTIVE_NAMES.size() - 1)
	var team: Array = args[-1]
	var details: Dictionary = {
		"reason": "departed" if event_name == &"team_sent" else "returned",
		"objective": ExpeditionState.OBJECTIVE_NAMES[objective],
		"team": ", ".join(PackedStringArray(team)),
	}
	if event_name == &"team_returned":
		details["success"] = args[2] == true
	return LogEntry.create(tick, &"expedition", StringName(str(args[0])), details)


## The "expedition" entry of a field event ("reason" "field_event", "event_id", "outcome",
## "name" of who rolled) on the team's world (m3-beyond-the-ring.md section 4, Risk model).
static func _field_event_entry(args: Array, tick: int) -> LogEntry:
	var details: Dictionary = {
		"reason": "field_event",
		"event_id": str(args[1]),
		"outcome": str(args[2]),
		"name": str(args[3]),
	}
	return LogEntry.create(tick, &"expedition", StringName(str(args[0])), details)


## The "expedition" entry of a check-in ("reason" "checked_in", "light", "serious"), a missed
## check-in ("missed"), a member deceased in a rescue ("deceased", "name"), a team rescued
## ("rescued", "survivors") or lost ("lost" or "no_answer"); the world is the team's
## (m3-beyond-the-ring.md section 4).
static func _expedition_entries(event_name: StringName, args: Array, tick: int) -> Array[LogEntry]:
	if args.is_empty():
		return []
	var world: StringName = StringName(
		str(args[-1] if event_name == &"member_deceased" else args[0])
	)
	var details: Dictionary = {}
	match event_name:
		&"team_checked_in":
			details = {"reason": "checked_in", "light": args[1], "serious": args[2]}
			details["day"] = str(args[3]) if args.size() > 3 else "finding"
		&"check_in_missed":
			details = {"reason": "missed"}
		&"member_deceased":
			details = {"reason": "deceased", "name": str(args[0])}
		&"team_rescued":
			details = {"reason": "rescued", "survivors": args[1]}
		_:
			details = {"reason": "lost" if str(args[1]) == "window" else "no_answer"}
	return [LogEntry.create(tick, &"expedition", world, details)]


## The "committee" entry of reports filed ("reason" "reports", "count" analysts), the
## commendation ("reason" "commendation", "amount_k") or a warning ("reason" the warning,
## "days" in the red in a row).
static func _committee_entry(
	event_name: StringName, args: Array, state: GameState, tick: int
) -> LogEntry:
	var value: int = args[0] if args.size() == 1 and args[0] is int else 0
	var details: Dictionary = {}
	match event_name:
		&"reports_filed":
			details = {"reason": "reports", "count": value}
		&"committee_commendation":
			details = {"reason": "commendation", "amount_k": value}
		_:
			details = {"reason": _text(args), "days": state.committee.days_in_red}
	return LogEntry.create(tick, &"committee", &"", details)


## The "staff" entry of a staff_changed event that is logged: the first room of a type took
## the waiting crew (&"auto_assigned") or a room coming down released its people
## (&"released"); args "reason", "room" (def id) and "count". Player moves are not logged.
static func _staff_entries(args: Array, tick: int) -> Array[LogEntry]:
	if args.size() != 3 or not args[2] is int:
		return []
	var reason: StringName = StringName(str(args[0]))
	if not reason in [StaffChanges.AUTO_ASSIGNED, StaffChanges.RELEASED]:
		return []
	var details: Dictionary = {"reason": String(reason), "room": str(args[1]), "count": args[2]}
	return [LogEntry.create(tick, &"staff", &"", details)]


## The "staff" entry of a hired person's arrival: "reason" "arrived", "name", "role" (role
## id) and "skill", read from the roster when the event is emitted. A soldier the Directorate
## lends ([param lent]) gets "reason" "lent" instead (m3-beyond-the-ring.md section 4).
static func _arrival_entries(
	args: Array, state: GameState, tick: int, lent: bool
) -> Array[LogEntry]:
	var person: PersonState = state.staff.find_person(StringName(_text(args)))
	if person == null:
		return []
	var details: Dictionary = {
		"reason": "lent" if lent else "arrived",
		"name": person.name,
		"role": String(person.role),
		"skill": person.skill
	}
	return [LogEntry.create(tick, &"staff", &"", details)]


## The "power" entry of a room that finished: charging lowered for it ("room", "charge_mw")
## or it stayed off ("room", "need_mw", "spare_mw"); or of a plant gone off (supply_dropped:
## "room", "charge_mw", "rooms_off"); "room" is its def id.
static func _finished_room_entries(
	event_name: StringName, args: Array, state: GameState, tick: int
) -> Array[LogEntry]:
	if args.is_empty() or not (args[0] is StringName or args[0] is String):
		return []
	var room: RoomState = state.base.find_room(StringName(str(args[0])))
	var details: Dictionary = {"room": "" if room == null else String(room.def_id)}
	if event_name == &"charging_lowered" and args.size() == 2 and args[1] is int:
		details["charge_mw"] = args[1]
	elif event_name == &"supply_dropped" and args.size() == 3 and args[1] is int and args[2] is int:
		details["charge_mw"] = args[1]
		details["rooms_off"] = args[2]
	elif args.size() == 3 and args[1] is int and args[2] is int:
		details["need_mw"] = args[1]
		details["spare_mw"] = args[2]
	else:
		return []
	return [LogEntry.create(tick, &"power", &"", details)]


## The "dial" entry of a dial_resolved event, plus a "lock" entry when it locked.
static func _dial_entries(args: Array, state: GameState, tick: int) -> Array[LogEntry]:
	if args.size() != 2 or not (args[0] is int and args[1] is String):
		return []
	var raw: int = args[0]
	var outcome: DialOutcome.Kind = raw as DialOutcome.Kind
	var details: Dictionary = {"address": args[1], "outcome": String(DialOutcome.to_key(outcome))}
	if not DialOutcome.is_lock(outcome):
		return [LogEntry.create(tick, &"dial", &"", details)]
	var world: StringName = _last_lock_world(state)
	var is_hostile: bool = outcome == DialOutcome.Kind.HOSTILE_LOCK
	return [
		LogEntry.create(tick, &"dial", world, details),
		LogEntry.create(tick, &"lock", world, {"hostile": is_hostile}),
	]


## The "power" entry of a capacitors_installed event: banks charging and capacity in MWh.
static func _power_entry(args: Array, state: GameState, tick: int) -> LogEntry:
	var capacity: float = args[0] if args.size() == 1 and args[0] is float else 0.0
	var details: Dictionary = {
		"banks": state.power.charge_rates.size(), "capacity_mwh": roundi(capacity)
	}
	return LogEntry.create(tick, &"power", &"", details)


## The world of the newest lock in the Dial Log, or empty when there is none.
static func _last_lock_world(state: GameState) -> StringName:
	var dial_log: Array[DialLogEntry] = state.gate.dial_log
	for index: int in range(dial_log.size() - 1, -1, -1):
		if DialOutcome.is_lock(dial_log[index].outcome):
			return dial_log[index].world_id
	return &""


## The first argument as text, or empty when there is none.
static func _text(args: Array) -> String:
	return str(args[0]) if args.size() >= 1 else ""
