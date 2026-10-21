class_name CommandQueue
extends RefCounted
## Holds submitted commands until the Simulation flushes them at the start of a tick.
## Minimal stub: M0-07 adds validation, rejection and logging.
## Bible: technical-architecture.md#simulation-clock-and-commands

## Emitted when a command fails validation. The Simulation forwards it.
@warning_ignore("unused_signal")
signal command_rejected(type: StringName, code: StringName)

var _pending: Array[Command] = []

## Enqueues [param command] for the next flush. Stub: always accepts a non-null command.
@warning_ignore("unused_parameter")
func submit(command: Command, state: GameState) -> CommandResult:  # gdlint: ignore=unused-argument
	if command == null:
		return CommandResult.fail(&"no_command")
	_pending.append(command)
	return CommandResult.ok()


## Applies every pending command to [param state] in submission order, then empties the
## queue. Commands submitted during the flush wait for the next one.
func flush(state: GameState) -> void:
	var batch: Array[Command] = _pending
	_pending = []
	for command: Command in batch:
		command.apply(state)
