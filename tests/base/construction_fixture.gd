class_name ConstructionFixture
extends RefCounted
## Shared setup for the construction tests: a new game over the real balance and room defs.
## Bible: docs/content/m2-base.md sections 1 and 4

const ROOM_DIR: String = "res://data/rooms/"


## A new game with the real balance, the starting base and every real RoomDef.
static func state() -> GameState:
	var balance: BalanceConfig = load("res://data/balance/balance_config.tres")
	var game := GameState.new_game(1, balance)
	game.balance = balance
	for file: String in DirAccess.get_files_at(ROOM_DIR):
		if file.ends_with(".tres"):
			var def: RoomDef = load(ROOM_DIR + file)
			game.room_defs[def.id] = def
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
