## Tests for PowerRules over the starting base: supply, allocation, spare and capacity, and
## that digging and building sites change none of them.
## Bible: docs/content/m2-base.md section 3
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()


## The starting base: one 30 MW plant; Gate 2 + Control 1 + Archive 1 = 4 MW allocated.
func test_starting_numbers() -> void:
	assert_float(PowerRules.supply_mw(_state)).is_equal(30.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(4.0)
	assert_float(PowerRules.spare_mw(_state)).is_equal(26.0)
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(0.0)


## Always-on rooms count even when their switch says off; an off room draws nothing.
func test_always_on_and_off_rooms() -> void:
	PowerFixture.first_room(_state, &"room_gate").powered_on = false
	PowerFixture.first_room(_state, &"room_archive").powered_on = false
	assert_float(PowerRules.allocated_mw(_state)).is_equal(3.0)


## Banks add capacity and their charge rate to allocation; one being demolished adds neither.
func test_banks_add_capacity_and_charging() -> void:
	PowerFixture.add_bank(_state, 10)
	var second: RoomState = PowerFixture.add_bank(_state, 5)
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(800.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(19.0)
	second.demolish_ticks_left = 5
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(400.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(14.0)
	assert_float(PowerRules.charge_per_tick_mwh(30.0)).is_equal(0.5)


## Digging a level and placing a room site change no power numbers.
func test_digging_and_building_draw_nothing() -> void:
	var before: Array[float] = _numbers()
	assert_bool(ConstructionFixture.run(_state, DigLevelCommand.new()).is_ok).is_true()
	var site := PlaceRoomCommand.create(&"room_physics_lab", 2, Vector2i(20, 12))
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
