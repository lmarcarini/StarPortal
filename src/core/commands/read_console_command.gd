class_name ReadConsoleCommand
extends Command
## While a wormhole is open, the player reads the far Ring's console: its log of recent dials
## adds one CONSOLE entry per listed world (ConsoleLog), already written for CAIRN, unless the
## book holds that address already. The listed worlds stay unnamed until locked. Each console is
## read once. Posts address_book_changed() when applied. In M1.5 the action needs no probe; the
## MOTH takes it over in M3.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"read_console"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(ReadConsoleCommand.new())


## Returns the addresses (GateAddress.key(), written for CAIRN) of the worlds the console of
## [param world_id] lists, in ConsoleLog order. [param state] must have its galaxy set.
static func listed_keys(state: GameState, world_id: StringName) -> Array[String]:
	var keys: Array[String] = []
	var galaxy: GalaxyCatalogue = state.galaxy
	var home_origin: int = galaxy.home().origin_glyph
	for listed_id: StringName in ConsoleLog.listed_worlds(world_id, galaxy):
		keys.append(galaxy.address_of(listed_id, home_origin).key())
	return keys


## Returns &"read_console".
func get_type() -> StringName:
	return TYPE


## Rejects a Ring with no open wormhole (&"not_locked") and a console already read
## (&"console_already_read").
func validate(state: GameState) -> CommandResult:
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"not_locked")
	var world_id: StringName = state.gate.connected_world_id
	if state.worlds.is_console_read(world_id):
		return CommandResult.fail(&"console_already_read", String(world_id))
	return CommandResult.ok()


## Adds the new addresses at the top of the book in log order, marks the console read and posts
## address_book_changed.
func apply(state: GameState) -> void:
	var world_id: StringName = state.gate.connected_world_id
	var keys: Array[String] = listed_keys(state, world_id)
	keys.reverse()
	for key: String in keys:
		if state.address_book.find(key) == null:
			var entry := AddressEntry.create(key, AddressEntry.Source.CONSOLE, world_id)
			state.address_book.entries.push_front(entry)
	state.worlds.consoles_read[world_id] = true
	state.events.post(&"address_book_changed", [])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
