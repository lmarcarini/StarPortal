class_name SimSystem
extends RefCounted
## Abstract base for a simulation system (power, gate, economy...). The Simulation calls
## tick() every tick, and on_day() / on_month() at day and month boundaries.
## Mutation happens only here and in Command.apply().
## Bible: technical-architecture.md#simulation-clock-and-commands


## Returns the system's stable id, e.g. &"power". Subclasses must override.
func get_id() -> StringName:
	assert(false, "SimSystem.get_id(): subclasses must override")
	return &""


## Advances the system by one tick against [param state]. Subclasses must override.
@warning_ignore("unused_parameter")
func tick(state: GameState) -> void:
	assert(false, "SimSystem.tick(): subclasses must override")


## Called at the first tick of each day. Default: does nothing.
@warning_ignore("unused_parameter")
func on_day(state: GameState) -> void:
	pass


## Called at the first tick of each month. Default: does nothing.
@warning_ignore("unused_parameter")
func on_month(state: GameState) -> void:
	pass
