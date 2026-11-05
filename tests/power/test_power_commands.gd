## Tests for SwitchRoomCommand and SetChargeRateCommand: allocation never exceeds supply,
## refusals carry a reason, always-on rooms and the last plant cannot be switched off.
## Bible: docs/content/m2-base.md section 3
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()


func _run(command: Command) -> CommandResult:
	return ConstructionFixture.run(_state, command)


func _id(def_id: StringName) -> StringName:
	return PowerFixture.first_room(_state, def_id).id


## Rooms without a switch, unknown rooms and sites are refused.
func test_switch_refusals() -> void:
	for def_id: StringName in [&"room_gate", &"room_control", &"room_corridor"]:
		assert_str(String(_run(SwitchRoomCommand.create(_id(def_id), false)).error_code)).is_equal(
			"no_switch"
		)
	var bank: RoomState = PowerFixture.add_bank(_state)
	assert_str(String(_run(SwitchRoomCommand.create(bank.id, false)).error_code)).is_equal(
		"no_switch"
	)
	assert_str(String(_run(SwitchRoomCommand.create(&"room_999", true)).error_code)).is_equal(
		"unknown_room"
	)
	var lab: RoomState = PowerFixture.lab(_state)
	lab.build_ticks_left = 3
	assert_str(String(_run(SwitchRoomCommand.create(lab.id, false)).error_code)).is_equal(
		"not_built"
	)


## Switching on is refused when the draw does not fit the spare; off then on works.
func test_switch_on_needs_spare_power() -> void:
	var lab: StringName = PowerFixture.lab(_state).id
	assert_bool(_run(SwitchRoomCommand.create(lab, false)).is_ok).is_true()
	assert_float(PowerRules.allocated_mw(_state)).is_equal(5.0)
	var bank: RoomState = PowerFixture.add_bank(_state, 25)
	var result: CommandResult = _run(SwitchRoomCommand.create(lab, true))
	assert_str(String(result.error_code)).is_equal("no_spare_power")
	assert_bool(_run(SetChargeRateCommand.create(bank.id, 20)).is_ok).is_true()
	assert_bool(_run(SwitchRoomCommand.create(lab, true)).is_ok).is_true()
	assert_float(PowerRules.allocated_mw(_state)).is_equal(PowerRules.supply_mw(_state))
	assert_int(_state.events.drain().size()).is_equal(3)


## The last running plant cannot be switched off; with a second plant one can, taking the
## lost supply from charging (m26-staff-and-money.md section 3).
func test_plants() -> void:
	var plant: StringName = _id(&"room_power_plant")
	assert_str(String(_run(SwitchRoomCommand.create(plant, false)).error_code)).is_equal(
		"last_plant"
	)
	_state.base.add_room(&"room_power_plant", 1, Vector2i(24, 2))
	assert_float(PowerRules.supply_mw(_state)).is_equal(60.0)
	var bank: RoomState = PowerFixture.add_bank(_state, 30)
	assert_bool(_run(SwitchRoomCommand.create(plant, false)).is_ok).is_true()
	assert_float(PowerRules.supply_mw(_state)).is_equal(30.0)
	assert_int(_state.power.charge_rates[bank.id]).is_equal(25)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(30.0)


## Charge rates: only for a standing bank, within 0..max, and within the spare.
func test_charge_rate_refusals() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 0)
	var lab: StringName = PowerFixture.lab(_state).id
	var cases: Array = [
		[SetChargeRateCommand.create(lab, 5), "not_a_bank"],
		[SetChargeRateCommand.create(&"room_999", 5), "unknown_room"],
		[SetChargeRateCommand.create(bank.id, 31), "rate_out_of_range"],
		[SetChargeRateCommand.create(bank.id, -1), "rate_out_of_range"],
		[SetChargeRateCommand.create(bank.id, 21), "no_spare_power"],
	]
	for case: Array in cases:
		var command: Command = case[0]
		assert_str(String(_run(command).error_code)).is_equal(case[1])
	assert_bool(_run(SetChargeRateCommand.create(bank.id, 20)).is_ok).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(20)
	bank.demolish_ticks_left = 2
	assert_str(String(_run(SetChargeRateCommand.create(bank.id, 0)).error_code)).is_equal(
		"not_built"
	)


## Both commands round trip through the factory.
func test_round_trip() -> void:
	for command: Command in [
		SwitchRoomCommand.create(&"room_4", false), SetChargeRateCommand.create(&"room_9", 26)
	]:
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var rebuilt: Result = CommandFactory.from_dict(data)
		assert_bool(rebuilt.is_ok).is_true()
		var copy: Command = rebuilt.value
		assert_dict(copy.to_dict()).is_equal(command.to_dict())
	assert_bool(CommandFactory.from_dict({"type": "switch_room", "room_id": "a"}).is_ok).is_false()
	var bad_rate := {"type": "set_charge_rate", "room_id": "a", "rate_mw": 1.5}
	assert_bool(CommandFactory.from_dict(bad_rate).is_ok).is_false()
