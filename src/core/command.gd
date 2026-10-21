class_name Command
extends RefCounted
## Abstract base for every player or system command: validates against the state, then
## applies. Subclasses override every method here; inheritance is one level deep only.
## Bible: technical-architecture.md#simulation-clock-and-commands


## Returns the command's stable type id, e.g. &"set_flag". Subclasses must override.
func get_type() -> StringName:
	assert(false, "Command.get_type(): subclasses must override")
	return &""


## Checks the command against [param state] without changing it. Subclasses must override.
@warning_ignore("unused_parameter")
func validate(state: GameState) -> CommandResult:
	assert(false, "Command.validate(): subclasses must override")
	return CommandResult.fail(&"not_implemented")


## Mutates [param state]. Only called after validate() succeeded. Subclasses must override.
@warning_ignore("unused_parameter")
func apply(state: GameState) -> void:
	assert(false, "Command.apply(): subclasses must override")


## Returns JSON-safe data for the command log; must include a "type" key.
## Subclasses must override.
func to_dict() -> Dictionary:
	assert(false, "Command.to_dict(): subclasses must override")
	return {}
