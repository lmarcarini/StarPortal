class_name PowerFixture
extends RefCounted
## Shared power setup for tests: the real RoomDefs and a built Capacitor Bank with a chosen
## charge rate.
## Bible: docs/content/m2-base.md section 3

const ROOM_DIR: String = "res://data/rooms/"
## Where add_bank() puts banks: level 1, a free strip near the top of the grid.
const BANK_ROW: int = 0


## Fills [param state]'s room_defs with every real RoomDef when it has none.
static func load_room_defs(state: GameState) -> void:
	if not state.room_defs.is_empty():
		return
	for file: String in DirAccess.get_files_at(ROOM_DIR):
		if file.ends_with(".tres"):
			var def: RoomDef = load(ROOM_DIR + file)
			state.room_defs[def.id] = def


## Adds a built Capacitor Bank to [param state]'s base charging at [param rate_mw] and returns
## it. Its placement is not checked: tests only need it to stand.
static func add_bank(state: GameState, rate_mw: int = 0) -> RoomState:
	load_room_defs(state)
	var column: int = state.power.charge_rates.size() * 4
	var bank: RoomState = state.base.add_room(
		StartingBase.CAPACITOR_BANK_DEF, 1, Vector2i(column, BANK_ROW)
	)
	state.power.charge_rates[bank.id] = rate_mw
	return bank


## Returns the first room of [param def_id] in [param state]'s base, or null.
static func first_room(state: GameState, def_id: StringName) -> RoomState:
	for room: RoomState in state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


## Returns the command that builds a Capacitor Bank in the capacitor alcove of [param state]
## (needs its balance and room_defs).
static func build_bank_in_alcove(state: GameState) -> PlaceRoomCommand:
	var bank: RoomDef = state.room_defs[StartingBase.CAPACITOR_BANK_DEF]
	var area: Rect2i = StartingBase.alcove(state.balance, bank)
	return PlaceRoomCommand.create(
		StartingBase.CAPACITOR_BANK_DEF, state.balance.capacitor_alcove_level, area.position
	)


## Sets every bank's charge rate in [param state] to [param mw].
static func set_charge(state: GameState, mw: int) -> void:
	for room_id: StringName in state.power.charge_rates:
		state.power.charge_rates[room_id] = mw


## Removes every Capacitor Bank from [param state]: no capacity, no charge rates.
static func remove_banks(state: GameState) -> void:
	for room_id: StringName in state.power.charge_rates.keys():
		state.base.remove_room(room_id)
	state.power.charge_rates.clear()
