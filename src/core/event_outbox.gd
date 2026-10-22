class_name EventOutbox
extends RefCounted
## Transient queue of domain events in GameState. Commands and systems post to it without
## touching a Node; the Simulation drains it at the end of each tick (and after a command
## applied while paused) and emits each event in posting order. Never saved.
## Bible: technical-architecture.md#architecture-overview,
## technical-architecture.md#simulation-clock-and-commands

var _events: Array[SimEvent] = []


## Posts event [param name] with signal arguments [param args] (copied), after every event
## already waiting. Usage: [code]state.events.post(&"gate_locked", [world_id])[/code].
func post(name: StringName, args: Array = []) -> void:
	_events.append(SimEvent.new(name, args.duplicate()))


## Returns the posted events in posting order and empties the outbox. Events posted while
## the returned ones are being emitted wait for the next drain.
func drain() -> Array[SimEvent]:
	var drained: Array[SimEvent] = _events
	_events = []
	return drained


## Returns how many events are waiting.
func size() -> int:
	return _events.size()
