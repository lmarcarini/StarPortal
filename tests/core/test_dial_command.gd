## Tests for DialCommand and CloseWormholeCommand: the rejections (busy Ring, malformed
## address, insufficient charge) change nothing, the bet needs the full lock energy, and both
## rebuild from to_dict() through CommandFactory.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## technical-architecture.md#errors-and-guard-clauses
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation
var _address: GateAddress
var _rejections: Array[Array] = []
var _event_count: int = 0


func before_test() -> void:
	_state = DialFixture.state()
	_simulation = DialFixture.simulation(_state)
	_address = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)
	_rejections.clear()
	_event_count = 0
	_simulation.command_rejected.connect(_on_rejected)
	_simulation.event_posted.connect(_on_event)


func after_test() -> void:
	CommandFactory.reset()


func _on_rejected(type: StringName, code: StringName) -> void:
	_rejections.append([type, code])


func _on_event(_name: StringName, _args: Array) -> void:
	_event_count += 1


## Submits [param command] and checks it is rejected with [param code], leaving the state and
## the outbox untouched.
func _assert_rejected(command: Command, code: StringName) -> void:
	var before: Dictionary = _state.to_dict()
	var result: CommandResult = _simulation.submit(command)
	assert_bool(result.is_ok).is_false()
	assert_str(String(result.error_code)).is_equal(String(code))
	assert_array(_rejections).is_equal([[DialCommand.TYPE, code]])
	assert_dict(_state.to_dict()).is_equal(before)
	assert_int(_event_count).is_equal(0)


## A missing address, a wrong seal count, a glyph out of range and a repeated glyph are
## &"bad_address".
func test_malformed_address_is_rejected() -> void:
	var bad: Array[GateAddress] = [
		null,
		GateAddress.create([1, 2, 3, 4, 5, 6], 7),
		GateAddress.create([1, 2, 3, 4, 5, 6, 36], 7),
		GateAddress.create([1, 2, 3, 4, 5, 6, 7], 1),
	]
	for address: GateAddress in bad:
		_rejections.clear()
		_assert_rejected(DialCommand.create(address), &"bad_address")


## A Ring that is DIALING or LOCKED is &"ring_busy".
func test_busy_ring_is_rejected() -> void:
	assert_bool(_simulation.submit(DialCommand.create(_address)).is_ok).is_true()
	_event_count = 0
	_assert_rejected(DialCommand.create(_address), &"ring_busy")
	_state.clock.is_paused = false
	_simulation.advance_tick()
	_simulation.advance_tick()
	_state.clock.is_paused = true
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_rejections.clear()
	_event_count = 0
	_assert_rejected(DialCommand.create(_address), &"ring_busy")


## The bank must hold the full lock energy: just below it is &"insufficient_charge", exactly
## it is accepted.
func test_insufficient_charge_is_rejected() -> void:
	var needed: float = GateQueries.lock_energy_mwh(_state, _address)
	_state.power.stored_mwh = needed - 0.001
	_assert_rejected(DialCommand.create(_address), &"insufficient_charge")
	_state.power.stored_mwh = needed
	assert_bool(DialCommand.create(_address).validate(_state).is_ok).is_true()


## A failed outcome's address still needs the full lock energy: the bet is the same.
func test_failed_outcomes_need_the_full_charge_too() -> void:
	var wrong := GateAddress.create(_address.coordinates, (_address.origin + 1) % 36)
	if not wrong.is_well_formed():
		wrong = GateAddress.create(_address.coordinates, (_address.origin + 2) % 36)
	_state.power.stored_mwh = GateQueries.lock_energy_mwh(_state, wrong) - 0.001
	_assert_rejected(DialCommand.create(wrong), &"insufficient_charge")


## DialCommand rebuilds from its JSON round-tripped to_dict(); bad data is malformed.
func test_dial_command_rebuilds_through_the_factory() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(DialCommand.create(_address).to_dict()))
	var result: Result = CommandFactory.from_dict(data)
	assert_bool(result.is_ok).is_true()
	var rebuilt: DialCommand = result.value
	assert_bool(rebuilt.address.equals(_address)).is_true()
	assert_dict(rebuilt.to_dict()).is_equal(DialCommand.create(_address).to_dict())
	for bad: Dictionary in [
		{"type": "dial"},
		{"type": "dial", "address": 3},
		{"type": "dial", "address": {"seals": [1, 2, 3]}},
		{"type": "dial", "address": {"seals": [1, 2, 3, 4, 5, 6, 7, 7.5]}},
	]:
		assert_str(String(CommandFactory.from_dict(bad).error_code)).is_equal("malformed_command")


## CloseWormholeCommand rebuilds from its to_dict().
func test_close_command_rebuilds_through_the_factory() -> void:
	var data: Dictionary = CloseWormholeCommand.new().to_dict()
	assert_dict(data).is_equal({"type": "close_wormhole"})
	var result: Result = CommandFactory.from_dict(data)
	assert_bool(result.is_ok).is_true()
	assert_object(result.value).is_instanceof(CloseWormholeCommand)


## The command log of a dial and a close replays to the same Ring.
func test_command_log_rebuilds_every_ring_command() -> void:
	_simulation.submit(DialCommand.create(_address))
	_state.clock.is_paused = false
	_simulation.advance_tick()
	_simulation.advance_tick()
	_state.clock.is_paused = true
	_simulation.submit(CloseWormholeCommand.new())
	var types: Array[String] = []
	for item: Dictionary in _simulation.commands.get_log():
		var command_data: Dictionary = item["command"]
		var rebuilt: Result = CommandFactory.from_dict(command_data)
		assert_bool(rebuilt.is_ok).is_true()
		var command: Command = rebuilt.value
		assert_dict(command.to_dict()).is_equal(command_data)
		types.append(String(command.get_type()))
	assert_array(types).is_equal(["dial", "close_wormhole"])
