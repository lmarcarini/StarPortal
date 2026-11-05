## Tests for the supply-drop rule (PowerSystem's shed, SwitchRoomCommand): losing a plant,
## switched off or demolished, lowers charging first, newest bank first, by just enough, and
## only then switches the newest rooms off; switching a plant off is refused only when rooms
## would have to go off. Allocation never exceeds supply, a message and a Log line follow, and
## the cached power totals stay equal to a fresh sum after each change.
## Bible: docs/content/m26-staff-and-money.md section 3
extends GdUnitTestSuite

var _state: GameState
var _plant: RoomState
var _older_bank: RoomState
var _newer_bank: RoomState


## Two plants (60 MW), the base's 5 MW, banks charging at 15 then 10 MW.
func before_test() -> void:
	_state = ConstructionFixture.state()
	PowerFixture.load_room_defs(_state)
	PowerFixture.remove_banks(_state)
	_plant = _state.base.add_room(&"room_power_plant", 1, Vector2i(24, 2))
	_older_bank = PowerFixture.add_bank(_state, 15)
	_newer_bank = PowerFixture.add_bank(_state, 10)
	_state.events.drain()


## [param count] labs on, 5 MW each (placement unchecked).
func _labs(count: int) -> Array[RoomState]:
	var labs: Array[RoomState] = []
	for index: int in count:
		labs.append(_state.base.add_room(&"room_research_lab", 2, Vector2i(4 + 5 * index, 2)))
	return labs


func _run(command: Command) -> CommandResult:
	return ConstructionFixture.run(_state, command)


func _assert_cache_is_fresh() -> void:
	assert_array(Array(PowerRules.totals(_state))).is_equal(Array(PowerRules._sum(_state)))
	assert_float(PowerRules.allocated_mw(_state)).is_less_equal(PowerRules.supply_mw(_state))


func _event(name: StringName) -> SimEvent:
	for event: SimEvent in _state.events.drain():
		if event.name == name:
			return event
	return null


## Switching a plant off takes its 30 MW from charging, newest bank first; rooms stay on.
func test_switch_off_lowers_charging_newest_first() -> void:
	var labs: Array[RoomState] = _labs(2)
	_assert_cache_is_fresh()
	assert_bool(_run(SwitchRoomCommand.create(_plant.id, false)).is_ok).is_true()
	assert_bool(labs[0].powered_on).is_true()
	assert_bool(labs[1].powered_on).is_true()
	assert_int(_state.power.charge_rates[_newer_bank.id]).is_equal(0)
	assert_int(_state.power.charge_rates[_older_bank.id]).is_equal(15)
	assert_float(PowerRules.allocated_mw(_state)).is_equal(30.0)
	var event: SimEvent = _event(&"supply_dropped")
	assert_array(event.args).is_equal([_plant.id, 15, 0])
	_assert_cache_is_fresh()


## Refused ("Switch rooms off first") when even zero charging leaves rooms short.
func test_switch_off_refused_only_when_rooms_would_go_off() -> void:
	var labs: Array[RoomState] = _labs(6)
	_state.power.charge_rates[_older_bank.id] = 0
	_state.power.charge_rates[_newer_bank.id] = 0
	var result: CommandResult = _run(SwitchRoomCommand.create(_plant.id, false))
	assert_str(String(result.error_code)).is_equal("no_spare_power")
	assert_bool(_plant.powered_on).is_true()
	labs[5].powered_on = false
	_state.power.charge_rates[_newer_bank.id] = 5
	assert_bool(_run(SwitchRoomCommand.create(_plant.id, false)).is_ok).is_true()
	assert_int(_state.power.charge_rates[_newer_bank.id]).is_equal(0)
	_assert_cache_is_fresh()


## Demolishing a plant when charging cannot cover it: charging goes to zero, then the newest
## room goes off; allocation fits and the event counts the room.
func test_demolish_takes_charging_then_newest_rooms() -> void:
	var labs: Array[RoomState] = _labs(6)
	_state.power.charge_rates[_older_bank.id] = 15
	_state.power.charge_rates[_newer_bank.id] = 10
	_assert_cache_is_fresh()
	assert_bool(_run(DemolishRoomCommand.create(_plant.id)).is_ok).is_true()
	assert_int(_state.power.charge_rates[_older_bank.id]).is_equal(0)
	assert_int(_state.power.charge_rates[_newer_bank.id]).is_equal(0)
	assert_bool(labs[5].powered_on).is_false()
	assert_bool(labs[4].powered_on).is_true()
	assert_float(PowerRules.allocated_mw(_state)).is_equal(30.0)
	var event: SimEvent = _event(&"supply_dropped")
	assert_array(event.args).is_equal([_plant.id, 0, 1])
	_assert_cache_is_fresh()
	PowerSystem.new(_state.balance).tick(_state)
	_assert_cache_is_fresh()


## Demolishing a plant that charging covers switches nothing off.
func test_demolish_covered_by_charging() -> void:
	_labs(2)
	assert_bool(_run(DemolishRoomCommand.create(_plant.id)).is_ok).is_true()
	assert_int(_state.power.charge_rates[_newer_bank.id]).is_equal(0)
	assert_int(_state.power.charge_rates[_older_bank.id]).is_equal(15)
	_assert_cache_is_fresh()


## A plant switched off directly (no command): the tick's shed takes from charging, silently.
func test_tick_shed_after_a_direct_change() -> void:
	_labs(1)
	_assert_cache_is_fresh()
	_plant.powered_on = false
	PowerSystem.new(_state.balance).tick(_state)
	assert_int(_state.power.charge_rates[_newer_bank.id]).is_equal(5)
	assert_int(_state.power.charge_rates[_older_bank.id]).is_equal(15)
	assert_object(_event(&"supply_dropped")).is_null()
	_assert_cache_is_fresh()


## The Log gets a "power" line, and it reads as the message does.
func test_log_line() -> void:
	_labs(1)
	_run(SwitchRoomCommand.create(_plant.id, false))
	var entries: Array[LogEntry] = []
	for event: SimEvent in _state.events.drain():
		entries.append_array(LogRules.entries_for(event.name, event.args, _state, 3))
	assert_int(entries.size()).is_equal(1)
	assert_dict(entries[0].args).is_equal(
		{"room": "room_power_plant", "charge_mw": 20, "rooms_off": 0}
	)
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_str(ArchiveLogRow.finished_room_line(entries[0].args)).is_equal(
		"Power Plant (diesel) off: charging lowered to 20 MW."
	)
	entries[0].args["rooms_off"] = 2
	assert_str(ArchiveLogRow.finished_room_line(entries[0].args)).is_equal(
		"Power Plant (diesel) off: charging stopped and 2 rooms switched off."
	)
	TranslationServer.set_locale(locale)
