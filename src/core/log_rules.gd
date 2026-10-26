class_name LogRules
extends RefCounted
## Pure rules of the operations log: which entries a domain event writes. They read the state
## only to name the world an event concerns (the Ring's last lock) and never change it.
## Bible: game-design.md#core-loop (Archive: the operations log)


## Returns the entries domain event [param event_name] with [param args] writes at
## [param tick], in order; empty for events the log ignores. A dial writes a "dial" entry
## (address key and outcome key; the world only on a lock, so a failure never names it), and a
## lock also writes a "lock" entry. Closes, horizon records and console reads name the world of
## the Ring's last lock in [param state].
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
	return []


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


## The "power" entry of a capacitors_installed event: banks installed and capacity in MWh.
static func _power_entry(args: Array, state: GameState, tick: int) -> LogEntry:
	var capacity: float = args[0] if args.size() == 1 and args[0] is float else 0.0
	var details: Dictionary = {
		"banks": state.power.banks_installed, "capacity_mwh": roundi(capacity)
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
