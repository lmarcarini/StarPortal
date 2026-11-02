## Tests for PowerRules over the starting base: supply, allocation, spare and capacity, and
## that digging and building sites change none of them.
## Bible: docs/content/m2-base.md section 3, docs/content/m25-lean-start.md sections 1 and 6
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()


## The starting base: one 30 MW plant; Gate 5 + Control 0 = 5 MW allocated, 25 MW spare
## (m25-lean-start.md section 1).
func test_starting_numbers() -> void:
	assert_float(PowerRules.supply_mw(_state)).is_equal(30.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(5.0)
	assert_float(PowerRules.spare_mw(_state)).is_equal(25.0)
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(0.0)


## Always-on rooms count even when their switch says off; an off room draws nothing.
func test_always_on_and_off_rooms() -> void:
	PowerFixture.lab(_state)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(10.0)
	PowerFixture.first_room(_state, &"room_gate").powered_on = false
	PowerFixture.lab(_state).powered_on = false
	assert_float(PowerRules.allocated_mw(_state)).is_equal(5.0)


## Banks add capacity and their charge rate to allocation; one being demolished adds neither.
func test_banks_add_capacity_and_charging() -> void:
	PowerFixture.add_bank(_state, 10)
	var second: RoomState = PowerFixture.add_bank(_state, 5)
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(800.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(20.0)
	second.demolish_ticks_left = 5
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(400.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(15.0)
	assert_float(PowerRules.charge_per_tick_mwh(30.0)).is_equal(0.5)


## Digging a level and placing a room site change no power numbers.
func test_digging_and_building_draw_nothing() -> void:
	ConstructionFixture.unlock_all(_state)
	var before: Array[float] = _numbers()
	assert_bool(ConstructionFixture.run(_state, DigLevelCommand.new()).is_ok).is_true()
	var site := PlaceRoomCommand.create(&"room_research_lab", 1, PowerFixture.LAB_ORIGIN)
	assert_bool(ConstructionFixture.run(_state, site).is_ok).is_true()
	var bank_site: PlaceRoomCommand = PowerFixture.build_first_bank(_state)
	assert_bool(ConstructionFixture.run(_state, bank_site).is_ok).is_true()
	assert_array(_numbers()).is_equal(before)


func _numbers() -> Array[float]:
	return [
		PowerRules.supply_mw(_state),
		PowerRules.allocated_mw(_state),
		PowerRules.capacity_mwh(_state),
	]
