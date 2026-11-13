## Tests for the power, Ring and expedition modifiers (M4-24): plant_output_mw,
## charge_rate_pct, dial_cost_pct (dial and hold), wormhole_minutes, field_check_bonus and
## moth_battery_pct at 0, positive and negative.
## Bible: docs/content/m4-core-systems.md section 6
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()


func _give(key: StringName, amount: int) -> void:
	var modifier := ModifierEffect.new()
	modifier.key = key
	modifier.amount = amount
	var project := ResearchDef.new()
	project.id = StringName("project_" + String(key))
	project.effects = [modifier]
	_state.research_defs[project.id] = project
	_state.research.done.erase(project.id)
	if amount != 0:
		_state.research.done.append(project.id)
	_state.modifiers.signature = []


func _plants() -> int:
	var count: int = 0
	for room: RoomState in PowerRules.powered_rooms(_state):
		var def: RoomDef = _state.room_defs[room.def_id]
		if def.power_output_mw > 0.0 and room.build_ticks_left == 0:
			count += 1
	return count


func test_plant_output() -> void:
	var supply: float = PowerRules.totals(_state)[0]
	_give(&"plant_output_mw", 2)
	assert_float(PowerRules.totals(_state)[0]).is_equal(supply + 2.0 * _plants())
	_give(&"plant_output_mw", -1)
	assert_float(PowerRules.totals(_state)[0]).is_equal(supply - 1.0 * _plants())
	_give(&"plant_output_mw", 0)
	assert_float(PowerRules.totals(_state)[0]).is_equal(supply)


func test_charge_rate_cap() -> void:
	var def := RoomDef.new()
	def.max_charge_rate_mw = 10.0
	assert_int(PowerRules.max_charge_mw(_state, def)).is_equal(10)
	_give(&"charge_rate_pct", 50)
	assert_int(PowerRules.max_charge_mw(_state, def)).is_equal(15)
	_give(&"charge_rate_pct", -50)
	assert_int(PowerRules.max_charge_mw(_state, def)).is_equal(5)


func test_dial_cost_and_drain() -> void:
	var address: GateAddress = DialFixture.address_of(_state.galaxy, &"world_lintel")
	var energy: float = GateQueries.lock_energy_mwh(_state, address)
	_give(&"dial_cost_pct", -25)
	assert_float(GateQueries.lock_energy_mwh(_state, address)).is_equal_approx(energy * 0.75, 0.001)
	_give(&"dial_cost_pct", 20)
	assert_float(GateQueries.lock_energy_mwh(_state, address)).is_equal_approx(energy * 1.2, 0.001)
	_state.gate.mode = GateState.RingMode.LOCKED
	var drain: float = _state.balance.open_drain_mw_8
	assert_float(PowerRules.drain_mw(_state)).is_equal_approx(drain * 1.2, 0.001)
	_give(&"dial_cost_pct", 0)
	assert_float(PowerRules.drain_mw(_state)).is_equal(drain)


func test_wormhole_minutes() -> void:
	var base: int = _state.balance.max_open_ticks
	assert_int(GateQueries.max_open_ticks(_state)).is_equal(base)
	_give(&"wormhole_minutes", 15)
	assert_int(GateQueries.max_open_ticks(_state)).is_equal(base + 15)
	_give(&"wormhole_minutes", -base - 10)
	assert_int(GateQueries.max_open_ticks(_state)).is_equal(1)


func test_field_check_bonus_reaches_the_roll() -> void:
	(
		assert_int(FieldCheck.chance(2 + ModifierRules.total(_state, &"field_check_bonus"), 2))
		. is_equal(50)
	)
	_give(&"field_check_bonus", 1)
	(
		assert_int(FieldCheck.chance(2 + ModifierRules.total(_state, &"field_check_bonus"), 2))
		. is_equal(65)
	)
	_give(&"field_check_bonus", -1)
	(
		assert_int(FieldCheck.chance(2 + ModifierRules.total(_state, &"field_check_bonus"), 2))
		. is_equal(35)
	)


func test_moth_battery() -> void:
	assert_int(MothRules.battery_minutes(_state)).is_equal(MothRules.BATTERY_MINUTES)
	_give(&"moth_battery_pct", 50)
	assert_int(MothRules.battery_minutes(_state)).is_equal(30)
	_give(&"moth_battery_pct", -50)
	assert_int(MothRules.battery_minutes(_state)).is_equal(10)
	var run: MothRun = MothRun.create(&"world_lintel")
	run.battery_left = 80
	assert_array(MothRun.validate_dict(run.to_dict())).is_empty()
	run.battery_left = 81
	assert_array(MothRun.validate_dict(run.to_dict())).is_not_empty()
