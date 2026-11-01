## Tests for PowerSystem: banks charge at their rate up to capacity, an open wormhole drains
## them, a completed bank takes the spare supply, a gone bank is forgotten and allocation is
## brought back within supply.
## Bible: docs/content/m2-base.md section 3
extends GdUnitTestSuite

const TOLERANCE: float = 1e-9

var _system: PowerSystem
var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()
	_system = PowerSystem.new(_state.balance)


func _tick(count: int) -> void:
	for index: int in count:
		_system.tick(_state)


## The system's id is power.
func test_id() -> void:
	assert_str(String(_system.get_id())).is_equal("power")


## A bank charging at 26 MW holds 260 MWh after 10 hours and stops at 400 exactly.
func test_bank_charges_at_its_rate_up_to_capacity() -> void:
	PowerFixture.add_bank(_state, 26)
	_tick(600)
	assert_float(_state.power.stored_mwh).is_equal_approx(260.0, TOLERANCE)
	_tick(500)
	assert_float(_state.power.stored_mwh).is_equal(400.0)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(30.0)


## An open wormhole drains 20 MWh per hour from the capacitors, less the charging; at 0 it
## stops.
func test_open_wormhole_drains_the_capacitors() -> void:
	PowerFixture.add_bank(_state, 5)
	_state.power.stored_mwh = 100.0
	_state.gate.mode = GateState.RingMode.LOCKED
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(85.0, TOLERANCE)
	_tick(60 * 7)
	assert_float(_state.power.stored_mwh).is_equal(0.0)


## DIALING does not drain.
func test_dialing_does_not_drain() -> void:
	PowerFixture.add_bank(_state, 26)
	_state.gate.mode = GateState.RingMode.DIALING
	_tick(60)
	assert_float(_state.power.stored_mwh).is_equal_approx(26.0, TOLERANCE)


## No bank: nothing is stored, nothing is posted, nothing is NaN.
func test_no_bank_stores_nothing() -> void:
	_state.gate.mode = GateState.RingMode.LOCKED
	_tick(120)
	assert_float(_state.power.stored_mwh).is_equal(0.0)
	assert_int(_state.events.size()).is_equal(0)


## A completed bank takes the spare supply (30 - 4 = 26 MW) once, posts capacitors_installed
## with the capacity and a pause request, then charges.
func test_completed_bank_takes_the_spare_supply() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state)
	_state.power.charge_rates.erase(bank.id)
	_tick(1)
	assert_int(_state.power.charge_rates[bank.id]).is_equal(26)
	var events: Array[SimEvent] = _state.events.drain()
	var names: Array[String] = []
	for event: SimEvent in events:
		names.append(String(event.name))
	assert_array(names).is_equal(
		["capacitors_installed", "pause_requested", "power_allocation_changed"]
	)
	assert_array(events[0].args).is_equal([400.0])
	assert_array(events[1].args).is_equal([&"capacitors_installed"])
	_tick(59)
	assert_float(_state.power.stored_mwh).is_equal_approx(26.0, TOLERANCE)
	assert_int(_state.events.size()).is_equal(0)


## A bank under construction neither charges nor counts.
func test_unbuilt_bank_does_nothing() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state)
	_state.power.charge_rates.erase(bank.id)
	bank.build_ticks_left = 10
	_tick(5)
	assert_bool(_state.power.charge_rates.has(bank.id)).is_false()
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(0.0)


## A bank being demolished loses its rate, its capacity and the charge above what is left.
func test_demolished_bank_loses_its_energy() -> void:
	var first: RoomState = PowerFixture.add_bank(_state, 10)
	PowerFixture.add_bank(_state, 10)
	_state.power.stored_mwh = 700.0
	first.demolish_ticks_left = 30
	_tick(1)
	assert_bool(_state.power.charge_rates.has(first.id)).is_false()
	assert_float(PowerRules.capacity_mwh(_state)).is_equal(400.0)
	assert_float(_state.power.stored_mwh).is_equal(400.0)


## A room completing beyond the supply is switched off; then, if still over, the newest
## switchable rooms go off and charge rates come down until allocation fits.
func test_over_allocation_is_shed() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 26)
	var lab: RoomState = _state.base.add_room(&"room_physics_lab", 2, Vector2i(20, 2))
	_tick(1)
	assert_bool(lab.powered_on).is_false()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(26)
	assert_int(_state.events.size()).is_equal(1)
	_state.power.charge_rates[bank.id] = 30
	_tick(1)
	assert_bool(PowerFixture.first_room(_state, &"room_archive").powered_on).is_false()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(27)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(PowerRules.supply_mw(_state))
