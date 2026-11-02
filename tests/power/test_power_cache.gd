## Tests for the cached power totals (issue #159): after each kind of change that affects
## allocation, the cached PowerRules.totals() equals a fresh sum, and a PowerSystem tick on the
## cached state ends where a tick on a freshly loaded copy (empty cache) does. The cache is
## memory only: it never reaches the save.
## Bible: technical-architecture.md#functional-core-stateful-shell, docs/content/m2-base.md
## section 3
extends GdUnitTestSuite

var _state: GameState
var _system: PowerSystem


func before_test() -> void:
	_state = ConstructionFixture.state()
	_system = PowerSystem.new(_state.balance)
	PowerFixture.add_bank(_state, 10)
	_tick(3)


func _tick(count: int) -> void:
	for index: int in count:
		_system.tick(_state)


func _run(command: Command) -> void:
	assert_bool(ConstructionFixture.run(_state, command).is_ok).is_true()


## Checks the cached totals equal a fresh sum, then that one tick on the cached state and one
## on a reloaded copy (no cache) give the same state.
func _assert_cache_is_fresh() -> void:
	assert_array(Array(PowerRules.totals(_state))).is_equal(Array(PowerRules._sum(_state)))
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var copy: GameState = GameState.from_dict(data)
	copy.balance = _state.balance
	copy.room_defs = _state.room_defs
	_system.tick(_state)
	_system.tick(copy)
	assert_dict(copy.to_dict()).is_equal(_state.to_dict())
	assert_array(Array(PowerRules.totals(_state))).is_equal(Array(PowerRules._sum(_state)))


## A second call with nothing changed returns the cached sums.
func test_unchanged_state_reuses_the_cache() -> void:
	PowerRules.totals(_state)
	_state.power.totals_cache[PowerRules.SUPPLY] = 999.0
	assert_float(PowerRules.supply_mw(_state)).is_equal(999.0)


## A room placed as a site, then finished.
func test_room_built_and_finished() -> void:
	var lab: RoomState = _state.base.add_room(&"room_physics_lab", 2, Vector2i(20, 2))
	lab.build_ticks_left = 5
	_assert_cache_is_fresh()
	lab.build_ticks_left = 1
	ConstructionSystem.new().tick(_state)
	assert_bool(lab.is_built()).is_true()
	_assert_cache_is_fresh()


## A room switched off and on, by command and directly.
func test_room_switched() -> void:
	var archive: RoomState = PowerFixture.first_room(_state, &"room_archive")
	_run(SwitchRoomCommand.create(archive.id, false))
	_assert_cache_is_fresh()
	archive.powered_on = true
	_assert_cache_is_fresh()


## A plant switched off: supply drops and the shed follows.
func test_plant_change() -> void:
	var plant_b: RoomState = _state.base.add_room(&"room_power_plant", 2, Vector2i(6, 11))
	_assert_cache_is_fresh()
	plant_b.powered_on = false
	_assert_cache_is_fresh()
	PowerFixture.first_room(_state, &"room_power_plant").powered_on = false
	_assert_cache_is_fresh()


## A charge rate set, by command and directly.
func test_rate_set() -> void:
	var bank: StringName = _state.power.charge_rates.keys()[0]
	_run(SetChargeRateCommand.create(bank, 4))
	_assert_cache_is_fresh()
	_state.power.charge_rates[bank] = 7
	_assert_cache_is_fresh()


## A room demolished: started, then finished and removed.
func test_room_demolished() -> void:
	var bank: RoomState = PowerFixture.first_room(_state, StartingBase.CAPACITOR_BANK_DEF)
	_run(DemolishRoomCommand.create(bank.id))
	_assert_cache_is_fresh()
	bank.demolish_ticks_left = 1
	ConstructionSystem.new().tick(_state)
	assert_object(_state.base.find_room(bank.id)).is_null()
	_assert_cache_is_fresh()


## A load gives a new PowerState with an empty cache, and the cache is never saved.
func test_load_starts_cold_and_cache_is_not_saved() -> void:
	PowerRules.totals(_state)
	var data: Dictionary = _state.power.to_dict()
	assert_array(data.keys()).contains_exactly_in_any_order(["stored_mwh", "charge_rates"])
	var loaded: PowerState = PowerState.from_dict(data)
	assert_int(loaded.totals_revision).is_equal(-1)
	assert_bool(loaded.totals_cache.is_empty()).is_true()
