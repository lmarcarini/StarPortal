## Tests for QueueAddressCommand and UnqueueAddressCommand: add, duplicate rejected, the 21st
## rejected, remove, dial_queue_changed posted on each change, and both rebuild from to_dict()
## through CommandFactory.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _changes: int = 0


func before_test() -> void:
	_state = GameState.new_game(1)
	_state.clock.is_paused = true
	_simulation = Simulation.new(_state)
	_changes = 0
	_simulation.event_posted.connect(_on_event)


func after_test() -> void:
	CommandFactory.reset()


func _on_event(event_name: StringName, args: Array) -> void:
	assert_str(String(event_name)).is_equal("dial_queue_changed")
	assert_array(args).is_empty()
	_changes += 1


## The [param index]th distinct well-formed address: seals index .. index + 7, wrapped.
func _address(index: int) -> GateAddress:
	var coordinates: Array[int] = []
	for seal: int in 7:
		coordinates.append((index + seal) % 36)
	return GateAddress.create(coordinates, (index + 7) % 36)


func _queue(address: GateAddress) -> CommandResult:
	return _simulation.submit(QueueAddressCommand.create(address))


## Queueing appends a copy and posts dial_queue_changed once.
func test_add() -> void:
	var address: GateAddress = _address(0)
	assert_bool(_queue(address).is_ok).is_true()
	assert_int(_state.gate.dial_queue.size()).is_equal(1)
	assert_bool(_state.gate.dial_queue[0].equals(address)).is_true()
	assert_object(_state.gate.dial_queue[0]).is_not_same(address)
	assert_int(_changes).is_equal(1)


## The same address twice is &"already_queued" and changes nothing.
func test_duplicate_rejected() -> void:
	_queue(_address(3))
	var result: CommandResult = _queue(_address(3))
	assert_str(String(result.error_code)).is_equal("already_queued")
	assert_int(_state.gate.dial_queue.size()).is_equal(1)
	assert_int(_changes).is_equal(1)


## Twenty addresses fit; the 21st is &"queue_full".
func test_twenty_first_rejected() -> void:
	for index: int in QueueAddressCommand.MAX_QUEUE:
		assert_bool(_queue(_address(index)).is_ok).is_true()
	assert_int(QueueAddressCommand.MAX_QUEUE).is_equal(20)
	var result: CommandResult = _queue(_address(20))
	assert_str(String(result.error_code)).is_equal("queue_full")
	assert_int(_state.gate.dial_queue.size()).is_equal(20)
	assert_int(_changes).is_equal(20)


## A malformed or missing address is &"bad_address".
func test_bad_address_rejected() -> void:
	var bad: Array[GateAddress] = [null, GateAddress.create([1, 1, 2, 3, 4, 5, 6], 7)]
	for address: GateAddress in bad:
		assert_str(String(_queue(address).error_code)).is_equal("bad_address")
	assert_str(String(_simulation.submit(UnqueueAddressCommand.create(null)).error_code)).is_equal(
		"bad_address"
	)
	assert_int(_changes).is_equal(0)


## Removing keeps the others in order and posts dial_queue_changed; an address not queued is
## &"not_queued".
func test_remove() -> void:
	for index: int in 3:
		_queue(_address(index))
	assert_bool(_simulation.submit(UnqueueAddressCommand.create(_address(1))).is_ok).is_true()
	assert_int(_state.gate.dial_queue.size()).is_equal(2)
	assert_bool(_state.gate.dial_queue[0].equals(_address(0))).is_true()
	assert_bool(_state.gate.dial_queue[1].equals(_address(2))).is_true()
	assert_int(_changes).is_equal(4)
	var result: CommandResult = _simulation.submit(UnqueueAddressCommand.create(_address(1)))
	assert_str(String(result.error_code)).is_equal("not_queued")
	assert_int(_changes).is_equal(4)


## Both commands rebuild from their JSON round-tripped to_dict() through CommandFactory.
func test_rebuild_through_the_factory() -> void:
	var commands: Array[Command] = [
		QueueAddressCommand.create(_address(4)), UnqueueAddressCommand.create(_address(4))
	]
	for command: Command in commands:
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var result: Result = CommandFactory.from_dict(data)
		assert_bool(result.is_ok).is_true()
		var rebuilt: Command = result.value
		assert_str(String(rebuilt.get_type())).is_equal(String(command.get_type()))
		assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
		var bad: Dictionary = {"type": String(command.get_type()), "address": {"seals": []}}
		assert_str(String(CommandFactory.from_dict(bad).error_code)).is_equal("malformed_command")
