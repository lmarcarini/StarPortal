## Tests for the finishing-room rule (FinishingPower): a room that finishes switches on taking
## power from charging first, newest bank first and by just enough; it never switches another
## room off; with not enough even at zero charging it finishes off; plant loss still sheds the
## newest rooms. Also the opening's bank-then-lab sequence (lock about 17.3 h in).
## Bible: docs/content/m25-lean-start.md sections 1 and 3
extends GdUnitTestSuite

## SILL's lock energy in MWh (m25-lean-start.md section 1).
const SILL_MWH: float = 366.6

var _state: GameState


func before_test() -> void:
	_state = ConstructionFixture.state()


## Adds a [param def_id] site on Level 2 with one tick left (placement unchecked).
func _site(def_id: StringName, column: int = 20) -> RoomState:
	var room: RoomState = _state.base.add_room(def_id, 2, Vector2i(column, 2))
	room.build_ticks_left = 1
	return room


func _finish() -> void:
	ConstructionSystem.new().tick(_state)


func _events() -> Array[SimEvent]:
	return _state.events.drain()


func _event(name: StringName) -> SimEvent:
	for event: SimEvent in _events():
		if event.name == name:
			return event
	return null


## Spare 0, banks at 10 then 15: the lab's 5 MW comes off the newest bank only.
func test_lowers_the_newest_bank_by_just_enough() -> void:
	var older: RoomState = PowerFixture.add_bank(_state, 10)
	var newer: RoomState = PowerFixture.add_bank(_state, 15)
	var lab: RoomState = _site(&"room_research_lab")
	_finish()
	assert_bool(lab.powered_on).is_true()
	assert_int(_state.power.charge_rates[older.id]).is_equal(10)
	assert_int(_state.power.charge_rates[newer.id]).is_equal(10)
	assert_float(PowerRules.spare_mw(_state)).is_equal(0.0)
	var event: SimEvent = _event(&"charging_lowered")
	assert_object(event).is_not_null()
	assert_array(event.args).is_equal([lab.id, 20])


## When the newest bank has less than needed, the next newest gives the rest.
func test_spans_banks_newest_first() -> void:
	var older: RoomState = PowerFixture.add_bank(_state, 22)
	var newer: RoomState = PowerFixture.add_bank(_state, 3)
	_site(&"room_research_lab")
	_finish()
	assert_int(_state.power.charge_rates[newer.id]).is_equal(0)
	assert_int(_state.power.charge_rates[older.id]).is_equal(20)


## Some spare: only the shortfall comes off charging.
func test_uses_spare_first() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 22)
	_site(&"room_research_lab")
	_finish()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(20)


## Enough spare: nothing changes and nothing is said.
func test_enough_spare_changes_nothing() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 10)
	var lab: RoomState = _site(&"room_research_lab")
	_finish()
	assert_bool(lab.powered_on).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(10)
	assert_object(_event(&"charging_lowered")).is_null()


## A running Workshop, newer than the bank, stays on: no other room is ever switched off.
func test_never_switches_another_room_off() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 20)
	var workshop: RoomState = _state.base.add_room(&"room_workshop", 2, Vector2i(0, 2))
	var lab: RoomState = _site(&"room_research_lab")
	_finish()
	assert_bool(workshop.powered_on).is_true()
	assert_bool(lab.powered_on).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(15)


## Rooms already take the whole supply: the lab finishes off with the refusal reason, and the
## charge rates and other rooms stay as they were.
func test_finishes_off_when_zero_charging_is_not_enough() -> void:
	var bank: RoomState = PowerFixture.add_bank(_state, 0)
	var workshops: Array[RoomState] = []
	for column: int in [0, 6, 12, 18, 24]:
		workshops.append(_state.base.add_room(&"room_workshop", 3, Vector2i(column, 2)))
	assert_float(PowerRules.spare_mw(_state)).is_equal(0.0)
	var lab: RoomState = _site(&"room_research_lab", 30)
	_finish()
	assert_bool(lab.powered_on).is_false()
	for workshop: RoomState in workshops:
		assert_bool(workshop.powered_on).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(0)
	var event: SimEvent = _event(&"room_finished_off")
	assert_object(event).is_not_null()
	assert_array(event.args).is_equal([lab.id, 5, 0])


## Losing a plant takes from charging first too (m26-staff-and-money.md section 3): the rooms
## stay on and the bank gives up just the lost supply.
func test_plant_loss_takes_from_charging_first() -> void:
	var plant_b: RoomState = _state.base.add_room(&"room_power_plant", 3, Vector2i(0, 2))
	var bank: RoomState = PowerFixture.add_bank(_state, 30)
	var older: RoomState = _state.base.add_room(&"room_workshop", 2, Vector2i(0, 2))
	var newer: RoomState = _state.base.add_room(&"room_research_lab", 2, Vector2i(20, 2))
	assert_float(PowerRules.spare_mw(_state)).is_equal(15.0)
	plant_b.demolish_ticks_left = 30
	PowerSystem.settle(_state)
	assert_bool(newer.powered_on).is_true()
	assert_bool(older.powered_on).is_true()
	assert_int(_state.power.charge_rates[bank.id]).is_equal(15)


## The log gets a "power" line for each case.
func test_log_lines() -> void:
	PowerFixture.add_bank(_state, 25)
	var lab: RoomState = _site(&"room_research_lab")
	_finish()
	var entries: Array[LogEntry] = []
	for event: SimEvent in _events():
		entries.append_array(LogRules.entries_for(event.name, event.args, _state, 7))
	var found: Array[Dictionary] = []
	for entry: LogEntry in entries:
		if entry.kind == &"power":
			found.append(entry.args)
	assert_array(found).is_equal([{"room": String(lab.def_id), "charge_mw": 20}])


## The opening, bank then lab: the bank is done at 01:00 and charges at 25 MW; the lab, started
## then, finishes at 09:00 and takes 5 MW from charging; SILL's 366.6 MWh is ready about 17.3 h
## in (1,040 ticks).
func test_opening_bank_then_lab_locks_about_17_3_hours_in() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(1, defs.balance), defs)
	var simulation: Simulation = built.value
	var state: GameState = simulation.state
	assert_bool(_apply(state, PowerFixture.build_first_bank(state))).is_true()
	while state.power.charge_rates.is_empty():
		simulation.advance_tick()
	assert_int(state.clock.tick).is_equal(60)
	assert_bool(_apply(state, _lab_command(state))).is_true()
	var lab: RoomState = state.base.rooms[-1]
	while not lab.is_built():
		simulation.advance_tick()
	assert_int(state.clock.tick).is_equal(540)
	assert_bool(lab.powered_on).is_true()
	assert_float(PowerRules.charge_mw(state)).is_equal(20.0)
	assert_float(state.power.stored_mwh).is_equal_approx(200.0, 1e-6)
	while state.power.stored_mwh < SILL_MWH:
		simulation.advance_tick()
	assert_int(state.clock.tick).is_between(1035, 1045)


func _apply(state: GameState, command: Command) -> bool:
	return ConstructionFixture.run(state, command).is_ok


## A Research Lab placement on Level 1 that is valid now.
func _lab_command(state: GameState) -> PlaceRoomCommand:
	for y: int in state.base.grid_size.y:
		for x: int in state.base.grid_size.x:
			var command := PlaceRoomCommand.create(&"room_research_lab", 1, Vector2i(x, y))
			if command.validate(state).is_ok:
				return command
	return null
