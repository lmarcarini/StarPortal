class_name ConstructionFixture
extends RefCounted
## Shared setup for the construction tests: a new game over the real balance and room defs.
## Bible: docs/content/m2-base.md sections 1 and 4

const ROOM_DIR: String = "res://data/rooms/"
## Funds grown() starts with, in $k.
const GROWN_FUNDS_K: int = 12000
## Row and columns of the spine grown() lays on Levels 2 and 3, and its lift's origin.
const GROWN_SPINE_ROW: int = 15
const GROWN_SPINE_FIRST: int = 4
const GROWN_SPINE_LAST: int = 31
const GROWN_LIFT: Vector2i = Vector2i(32, 14)
## Where grown() puts a Quarters on Level 2: a room for overlap and stranding tests.
const GROWN_QUARTERS: Vector2i = Vector2i(12, 13)


## A new game with the real balance, the starting base, every real RoomDef and ResearchDef.
static func state() -> GameState:
	var balance: BalanceConfig = load("res://data/balance/balance_config.tres")
	var game := GameState.new_game(1, balance)
	game.balance = balance
	for file: String in DirAccess.get_files_at(ROOM_DIR):
		if file.ends_with(".tres"):
			var def: RoomDef = load(ROOM_DIR + file)
			game.room_defs[def.id] = def
	game.research_defs = UnlockFixture.research()
	return game


## [param game] after every M2.5 project (UnlockFixture.projects()): every room but the
## staff-locked ones (and the M4 storage rooms), digging down to Level 4, three banks and the
## fuel contract.
static func unlock_all(game: GameState) -> GameState:
	for project_id: StringName in UnlockFixture.projects():
		UnlockFixture.apply_project(game.unlocks, project_id)
	for storage: StringName in [&"room_artefact_vault", &"room_containment"]:
		UnlockRules.apply(game.unlocks, UnlockRules.EFFECT_UNLOCK_ROOM, storage)
	return game


## A grown base for the construction tests: a new game with every research unlock (and, for
## tests only, Quarters and Infirmary), $12,000k, and Levels 2 and 3 dug, each with a corridor
## spine on row 15 (columns 4-31) and one built lift shaft at (32, 14) on Levels 1-3; Level 2
## also holds a Quarters at (12, 13). Rooms come from add_room(), so the power cache sees them.
static func grown() -> GameState:
	var game: GameState = unlock_all(state())
	for def_id: StringName in UnlockRules.STAFF_LOCKED:
		UnlockRules.apply(game.unlocks, UnlockRules.EFFECT_UNLOCK_ROOM, def_id)
	game.budget.funds_k = GROWN_FUNDS_K
	for level: int in [2, 3]:
		game.base.levels.append(LevelState.new())
		for column: int in range(GROWN_SPINE_FIRST, GROWN_SPINE_LAST + 1):
			game.base.add_room(StartingBase.CORRIDOR_DEF, level, Vector2i(column, GROWN_SPINE_ROW))
	for level: int in [1, 2, 3]:
		game.base.add_room(StartingBase.LIFT_DEF, level, GROWN_LIFT)
	game.base.add_room(&"room_quarters", 2, GROWN_QUARTERS)
	return game


## Validates and, when valid, applies [param command]; returns the validation result.
static func run(game: GameState, command: Command) -> CommandResult:
	var result: CommandResult = command.validate(game)
	if result.is_ok:
		command.apply(game)
	return result


## Ticks [param system] [param ticks] times over [param game].
static func advance(game: GameState, system: ConstructionSystem, ticks: int) -> void:
	for index: int in ticks:
		system.tick(game)


## Names of the events waiting in [param game]'s outbox, drained.
static func event_names(game: GameState) -> Array[StringName]:
	var names: Array[StringName] = []
	for event: SimEvent in game.events.drain():
		names.append(event.name)
	return names
