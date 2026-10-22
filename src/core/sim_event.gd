class_name SimEvent
extends RefCounted
## A domain event posted by a command or system, waiting in the EventOutbox until the
## Simulation emits it at the end of the tick.
## Bible: technical-architecture.md#architecture-overview

## The event's signal name on the event bus, e.g. &"gate_locked".
var name: StringName
## That signal's arguments, in order.
var args: Array


## Creates an event named [param event_name] with arguments [param event_args].
func _init(event_name: StringName = &"", event_args: Array = []) -> void:
	name = event_name
	args = event_args
