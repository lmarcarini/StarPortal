class_name CommandQueue
extends RefCounted
## The only way commands reach the state. Validates each command on submit, applies it at
## once while the clock is paused or holds it for the next flush, re-validates it at flush
## time, and logs every applied command with its tick so a session can be replayed.
## Bible: technical-architecture.md#simulation-clock-and-commands

## Emitted when a command fails validation, on submit or at flush. The Simulation
## forwards it.
signal command_rejected(type: StringName, code: StringName)

var _pending: Array[Command] = []
var _log: Array[Dictionary] = []


## Validates [param command] against [param state]. A rejected command is reported through
## [signal command_rejected] and not queued. While running, a valid command waits for the
## next [method flush]. While paused, any commands still pending are flushed first, to
## keep submission order; the command is then validated again against the updated state
## and applies at once, or is rejected if a pending command invalidated it.
func submit(command: Command, state: GameState) -> CommandResult:
	assert(state != null, "CommandQueue.submit() needs a state")
	if command == null:
		return _reject(&"", CommandResult.fail(&"no_command"))
	var result: CommandResult = command.validate(state)
	if not result.is_ok:
		return _reject(command.get_type(), result)
	if not state.clock.is_paused:
		_pending.append(command)
		return result
	if _pending.is_empty():
		_apply(command, state)
		return result
	flush(state)
	return _validate_and_apply(command, state)


## Re-validates and applies every pending command to [param state] in submission order,
## then empties the queue. Commands that are no longer valid are dropped and reported
## through [signal command_rejected]. Commands submitted during the flush wait for the
## next one.
func flush(state: GameState) -> void:
	assert(state != null, "CommandQueue.flush() needs a state")
	var batch: Array[Command] = _pending
	_pending = []
	for command: Command in batch:
		_validate_and_apply(command, state)


## Returns a copy of the log of applied commands, oldest first. Each entry is
## [code]{"tick": int, "command": Dictionary}[/code], where "command" is the command's
## to_dict() and can be rebuilt with CommandFactory.from_dict().
func get_log() -> Array[Dictionary]:
	return _log.duplicate(true)


## Empties the log of applied commands. Pending commands are kept.
func clear_log() -> void:
	_log.clear()


## Returns how many valid commands are waiting for the next flush.
func pending_count() -> int:
	return _pending.size()


func _validate_and_apply(command: Command, state: GameState) -> CommandResult:
	var result: CommandResult = command.validate(state)
	if not result.is_ok:
		return _reject(command.get_type(), result)
	_apply(command, state)
	return result


func _apply(command: Command, state: GameState) -> void:
	command.apply(state)
	_log.append({"tick": state.clock.tick, "command": command.to_dict()})


func _reject(type: StringName, result: CommandResult) -> CommandResult:
	command_rejected.emit(type, result.error_code)
	return result
