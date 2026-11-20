class_name ProgressCounters
extends RefCounted
## Whole-number progress counters kept in GameState.flags, counted from domain events as the
## simulation drains them (M7): locks made, canisters sent, MOTH runs, expeditions sent,
## incursion warnings and alien conversations. Research "Shows when" conditions read them
## (CountAtLeastCondition). Never touches a Node.
## Bible: docs/content/research-and-progression.md sections 6 and 10

## Counter flag of each counted event.
const COUNTERS: Dictionary[StringName, StringName] = {
	&"canister_launched": &"count_canisters_sent",
	&"moth_launched": &"count_moth_runs",
	&"team_sent": &"count_expeditions_sent",
	&"incursion_warning": &"count_incursion_warnings",
}
## Counter of locks made (dial_resolved with a LOCK outcome).
const LOCKS: StringName = &"count_locks_made"
## Counter of conversations with aliens (not on the phone).
const ALIEN_TALKS: StringName = &"count_alien_conversations"


## Counts [param event_name] with [param args] into [param state]'s counters.
static func count(state: GameState, event_name: StringName, args: Array) -> void:
	if COUNTERS.has(event_name):
		bump(state, COUNTERS[event_name])
	elif event_name == &"dial_resolved" and not args.is_empty():
		if type_convert(args[0], TYPE_INT) == DialOutcome.Kind.LOCK:
			bump(state, LOCKS)
	elif event_name == &"conversation_started" and args.size() >= 2:
		if StringName(str(args[1])) != &"phone":
			bump(state, ALIEN_TALKS)


## Adds one to counter [param key].
static func bump(state: GameState, key: StringName) -> void:
	state.flags[key] = value(state, key) + 1


## The value of counter [param key] (0 when never counted).
static func value(state: GameState, key: StringName) -> int:
	var raw: Variant = state.flags.get(key, 0)
	if raw is float:
		return type_convert(raw, TYPE_INT)
	return raw if raw is int else 0
