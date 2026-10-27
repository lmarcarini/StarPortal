class_name LogState
extends RefCounted
## The operations log: every recorded event, oldest first, at most [constant CAP] entries (the
## oldest are dropped). The Simulation adds entries as it emits domain events.
## Saved shape: {"entries": [LogEntry]}.
## Bible: game-design.md#core-loop (Archive: the operations log),
## technical-architecture.md#data-model

## Most entries kept; adding past it drops the oldest.
const CAP: int = 2000

## Every entry, oldest first.
var entries: Array[LogEntry] = []


## Appends [param entry], dropping the oldest entries beyond [constant CAP].
func add(entry: LogEntry) -> void:
	entries.append(entry)
	var excess: int = entries.size() - CAP
	if excess > 0:
		entries = entries.slice(excess)


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var entry_data: Array[Dictionary] = []
	for entry: LogEntry in entries:
		entry_data.append(entry.to_dict())
	return {"entries": entry_data}


## Builds a log from saved [param data]; items that are not objects are skipped and only the
## newest [constant CAP] are kept. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> LogState:
	var log_state := LogState.new()
	var entry_data: Variant = data.get("entries")
	if not entry_data is Array:
		return log_state
	var list: Array = entry_data
	for item: Variant in list:
		if item is Dictionary:
			var item_data: Dictionary = item
			log_state.add(LogEntry.from_dict(item_data))
	return log_state


## Returns human-readable errors for saved [param data], empty when it is valid: "entries" an
## array of at most [constant CAP] valid LogEntry objects whose ticks never go back.
static func validate_dict(data: Dictionary) -> Array[String]:
	var entry_data: Variant = data.get("entries")
	if not entry_data is Array:
		return ["'entries' is missing or not an array"]
	var list: Array = entry_data
	if list.size() > CAP:
		return ["'entries' holds more than %d entries" % CAP]
	var errors: Array[String] = []
	var last_tick: float = 0.0
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("entries %d is not an object" % index)
			continue
		var item: Dictionary = list[index]
		var item_errors: Array[String] = LogEntry.validate_dict(item)
		for error: String in item_errors:
			errors.append("entries %d: %s" % [index, error])
		if item_errors.is_empty():
			var tick: float = item["tick"]
			if tick < last_tick:
				errors.append("entries %d 'tick' is earlier than the entry before" % index)
			last_tick = maxf(last_tick, tick)
	return errors


## Returns the newest tick in the log, or -1 when it is empty.
func last_tick() -> int:
	if entries.is_empty():
		return -1
	var newest: LogEntry = entries.back()
	return newest.tick
