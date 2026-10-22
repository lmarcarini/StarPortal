class_name SendTracker
extends RefCounted
## Follows the workbench's "Send to dial queue" commands that were accepted while the clock ran
## and so only apply, or are refused, at the next tick. View-local; nothing here is saved.
##
## A send resolves as SENT when its address shows up in the queue (dial_queue_changed), or with
## the refusal code of a queue_address rejection (command_rejected). Rejections carry no
## address, so one is matched to a waiting send: already_queued to the latest whose address is
## in the queue (the queue adds in submission order, so earlier ones were the ones applied),
## any other code to the earliest whose address is not. The workbench shows the result of the
## latest send once every waiting send has resolved.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands


## One send waiting for its tick.
class Entry:
	extends RefCounted
	## The address sent.
	var address: GateAddress = null
	## &"" while waiting, SENT, or a QueueAddressCommand refusal code.
	var outcome: StringName = &""


## Outcome of a send whose address reached the queue.
const SENT: StringName = &"sent"
## Refusal code QueueAddressCommand gives for an address already in the queue.
const ALREADY_QUEUED: StringName = &"already_queued"

var _entries: Array[Entry] = []


## Starts following a send of [param address].
func add(address: GateAddress) -> void:
	var entry := Entry.new()
	entry.address = address
	_entries.append(entry)


## Forgets every send, e.g. when a new simulation is shown.
func clear() -> void:
	_entries.clear()


## True while a send has not resolved.
func is_waiting() -> bool:
	return _entries.any(func(entry: Entry) -> bool: return entry.outcome.is_empty())


## Resolves the waiting sends whose address is now in [param queue] as SENT.
func on_queue_changed(queue: Array[GateAddress]) -> void:
	for entry: Entry in _entries:
		if entry.outcome.is_empty() and contains(queue, entry.address):
			entry.outcome = SENT


## Matches a queue_address refusal with [param code] to a waiting send; [param queue] is the
## queue at the time of the refusal.
func on_rejected(code: StringName, queue: Array[GateAddress]) -> void:
	var match_queued: bool = code == ALREADY_QUEUED
	var order: Array = range(_entries.size())
	if match_queued:
		order.reverse()
	for position: int in order:
		var entry: Entry = _entries[position]
		if entry.outcome.is_empty() and contains(queue, entry.address) == match_queued:
			entry.outcome = code
			return


## Returns the latest send's outcome and forgets every send, once none is waiting; &"" while
## one is, or when there is none.
func take_result() -> StringName:
	if _entries.is_empty() or is_waiting():
		return &""
	var latest: Entry = _entries.back()
	_entries.clear()
	return latest.outcome


## True when [param queue] holds an address equal to [param address].
static func contains(queue: Array[GateAddress], address: GateAddress) -> bool:
	return queue.any(func(queued: GateAddress) -> bool: return queued.equals(address))
