## Regression tests from the #149 review: the last running plant cannot be demolished, the
## shed restarts a stopped plant rather than leave the always-on rooms unpowered, allocation
## never exceeds supply on the tick a room finishes, and a just-finished bank takes a rate.
## Bible: docs/content/m2-base.md sections 3 and 4
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()


func _run(command: Command) -> CommandResult:
	return ConstructionFixture.run(_state, command)


## Two plants, A switched off: demolishing B, the last running plant, is refused.
func test_last_running_plant_cannot_be_demolished() -> void:
	var plant_a: RoomState = PowerFixture.first_room(_state, &"room_power_plant")
	var plant_b: RoomState = _state.base.add_room(&"room_power_plant", 2, Vector2i(6, 11))
	assert_bool(_run(SwitchRoomCommand.create(plant_a.id, false)).is_ok).is_true()
	var result: CommandResult = _run(DemolishRoomCommand.create(plant_b.id))
	assert_str(String(result.error_code)).is_equal("last_plant")
	assert_float(PowerRules.supply_mw(_state)).is_equal(30.0)


## If supply still drops below the always-on load, the shed switches a stopped plant back on,
## and a settled base posts no further power_allocation_changed.
func test_shed_restarts_a_stopped_plant_and_then_stays_quiet() -> void:
	var system := PowerSystem.new(_state.balance)
	var plant_a: RoomState = PowerFixture.first_room(_state, &"room_power_plant")
	var plant_b: RoomState = _state.base.add_room(&"room_power_plant", 2, Vector2i(6, 11))
	plant_a.powered_on = false
	plant_b.demolish_ticks_left = 30
	plant_b.powered_on = false
	assert_float(PowerRules.supply_mw(_state)).is_equal(0.0)
	system.tick(_state)
	assert_bool(plant_a.powered_on).is_true()
	assert_float(PowerRules.allocated_mw(_state)).is_less_equal(PowerRules.supply_mw(_state))
	assert_int(_state.events.drain().size()).is_equal(1)
	system.tick(_state)
	system.tick(_state)
	assert_int(_state.events.size()).is_equal(0)


## A room that finishes with no spare power is shed on the same tick it finishes.
func test_allocation_fits_on_the_tick_a_room_finishes() -> void:
	PowerFixture.add_bank(_state, 26)
	var lab: RoomState = _state.base.add_room(&"room_physics_lab", 2, Vector2i(20, 2))
	lab.build_ticks_left = 1
	ConstructionSystem.new().tick(_state)
	assert_bool(lab.is_built()).is_true()
	assert_float(PowerRules.allocated_mw(_state)).is_less_equal(PowerRules.supply_mw(_state))


## A bank that is built but has no rate yet can be given one straight away.
func test_finished_bank_rate_is_settable_at_once() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state)
	_state.power.charge_rates.erase(bank.id)
	assert_bool(_run(SetChargeRateCommand.create(bank.id, 10)).is_ok).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(10)
