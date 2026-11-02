class_name PowerFixture
extends RefCounted
## Shared power setup for tests: the real RoomDefs and a built Capacitor Bank with a chosen
## charge rate.
## Bible: docs/content/m2-base.md section 3

const ROOM_DIR: String = "res://data/rooms/"
## Where add_bank() puts banks: level 1, a free strip near the top of the grid.
const BANK_ROW: int = 0
## Where lab() puts the Research Lab: Level 1, west of the plant, against the spine.
const LAB_ORIGIN: Vector2i = Vector2i(0, 11)


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


## Returns [param state]'s first Research Lab, adding a built, switched-on one at LAB_ORIGIN
## when there is none: the switchable 5 MW room the power tests use (the lean start has none).
static func lab(state: GameState) -> RoomState:
	load_room_defs(state)
	var found: RoomState = first_room(state, &"room_research_lab")
	if found != null:
		return found
	return state.base.add_room(&"room_research_lab", 1, LAB_ORIGIN)


## Returns the first room of [param def_id] in [param state]'s base, or null.
static func first_room(state: GameState, def_id: StringName) -> RoomState:
	for room: RoomState in state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


## Returns the command that builds a Capacitor Bank of [param state] on the nearest valid spot
## to the Gate Room (BaseSpots.bank_spot), as the Gate Room's button does (needs room_defs).
static func build_first_bank(state: GameState) -> PlaceRoomCommand:
	var gate: RoomState = BaseSpots.gate_room(state.base)
	var spot: Vector2i = BaseSpots.bank_spot(state.base, state.room_defs)
	return PlaceRoomCommand.create(StartingBase.CAPACITOR_BANK_DEF, gate.level, spot)


## Sets every bank's charge rate in [param state] to [param mw].
static func set_charge(state: GameState, mw: int) -> void:
	for room_id: StringName in state.power.charge_rates:
		state.power.charge_rates[room_id] = mw


## Removes every Capacitor Bank from [param state]: no capacity, no charge rates.
static func remove_banks(state: GameState) -> void:
	for room_id: StringName in state.power.charge_rates.keys():
		state.base.remove_room(room_id)
	state.power.charge_rates.clear()
