## Tests for ReadConsoleCommand: while a wormhole is open it adds a CONSOLE entry per world the far
## Ring's console lists, written for CAIRN and unnamed until locked (dialing one locks it);
## addresses already in the book are kept as they are; it is refused when not locked or already
## read, reading twice adds nothing, and the read console survives a save and load.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown
extends GdUnitTestSuite

const SEED: int = 20_261_024
## A bank large enough for any dial in these tests.
const BIG_BANK_MWH: float = 1.0e9

var _simulation: Simulation
var _events: Array[StringName] = []


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build(GameState.new_game(SEED, defs.balance), defs).value
	var power: PowerState = _simulation.state.power
	power.banks_installed = 1
	power.capacity_mwh = BIG_BANK_MWH
	power.stored_mwh = BIG_BANK_MWH
	_events.clear()
	_simulation.event_posted.connect(
		func(event_name: StringName, _args: Array) -> void: _events.append(event_name)
	)


func _state() -> GameState:
	return _simulation.state


## The first open, unguarded procedural world.
func _reader_id() -> StringName:
	for record: WorldRecord in _state().galaxy.all_worlds():
		var is_open: bool = record.ring_status == WorldDef.RingStatus.OPEN
		if is_open and not record.is_authored and not record.is_guarded:
			return record.id
	return &""


func _address_of(world_id: StringName) -> GateAddress:
	var galaxy: GalaxyCatalogue = _state().galaxy
	return galaxy.address_of(world_id, galaxy.home().origin_glyph)


## Dials [param world_id] and runs the clock until the dial resolves.
func _dial(world_id: StringName) -> void:
	assert_bool(_simulation.submit(DialCommand.create(_address_of(world_id))).is_ok).is_true()
	_state().clock.is_paused = false
	while _state().gate.mode == GateState.RingMode.DIALING:
		_simulation.advance_tick()
	_state().clock.is_paused = true


## The first of [param ids] whose Ring is open, or &"".
func _first_open(ids: Array[StringName]) -> StringName:
	for id: StringName in ids:
		if _state().galaxy.get_world(id).ring_status == WorldDef.RingStatus.OPEN:
			return id
	return &""


func _read() -> CommandResult:
	return _simulation.submit(ReadConsoleCommand.new())


## Reading adds one unnamed CONSOLE entry per listed world, with the true CAIRN address, marks
## the console read and posts address_book_changed; dialing a listed address locks its world.
func test_read_adds_listed_addresses() -> void:
	var reader: StringName = _reader_id()
	_dial(reader)
	_events.clear()
	assert_bool(_read().is_ok).is_true()
	var listed := ConsoleLog.listed_worlds(reader, _state().galaxy)
	assert_int(_state().address_book.entries.size()).is_equal(listed.size() + 1)
	for index: int in listed.size():
		var entry: AddressEntry = _state().address_book.entries[index]
		assert_str(entry.address_key).is_equal(_address_of(listed[index]).key())
		assert_int(entry.source).is_equal(AddressEntry.Source.CONSOLE)
		assert_str(String(entry.source_id)).is_equal(String(reader))
		assert_str(String(entry.world_id)).is_empty()
		assert_int(_state().worlds.status_of(listed[index])).is_equal(
			WorldsState.WorldStatus.UNKNOWN
		)
	assert_bool(_state().worlds.is_console_read(reader)).is_true()
	assert_array(_events).contains_exactly([&"console_read", &"address_book_changed"])
	assert_array(GameState.validate_dict(_state().to_dict())).is_empty()
	_simulation.submit(CloseWormholeCommand.new())
	var target: StringName = _first_open(listed)
	assert_str(String(target)).is_not_empty()
	_dial(target)
	assert_int(_state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_str(String(_state().gate.connected_world_id)).is_equal(String(target))
	var dialed: AddressEntry = _state().address_book.find(_address_of(target).key())
	assert_int(dialed.source).is_equal(AddressEntry.Source.CONSOLE)
	assert_str(String(dialed.world_id)).is_equal(String(target))


## Refused while the Ring is idle or dialing.
func test_refused_when_not_locked() -> void:
	assert_str(String(_read().error_code)).is_equal("not_locked")
	_simulation.submit(DialCommand.create(_address_of(_reader_id())))
	assert_str(String(_read().error_code)).is_equal("not_locked")
	assert_array(_state().address_book.entries).is_empty()
	assert_array(_events).not_contains([&"console_read"])


## A second read is refused and adds nothing, also after closing and dialing the world again.
func test_second_read_is_refused() -> void:
	var reader: StringName = _reader_id()
	_dial(reader)
	_read()
	var before: Dictionary = _state().address_book.to_dict()
	assert_str(String(_read().error_code)).is_equal("console_already_read")
	_simulation.submit(CloseWormholeCommand.new())
	_dial(reader)
	assert_str(String(_read().error_code)).is_equal("console_already_read")
	var after: Dictionary = _state().address_book.to_dict()
	var after_entries: Array = after["entries"]
	var before_entries: Array = before["entries"]
	assert_int(after_entries.size()).is_equal(before_entries.size())
	assert_int(_events.count(&"console_read")).is_equal(1)


## An address already in the book keeps its entry; only the others are added.
func test_known_address_is_kept() -> void:
	var reader: StringName = _reader_id()
	var listed := ConsoleLog.listed_worlds(reader, _state().galaxy)
	var known_key: String = _address_of(listed[0]).key()
	var known := AddressEntry.create(known_key, AddressEntry.Source.DOCUMENT, &"doc_x")
	_state().address_book.entries.append(known)
	_dial(reader)
	_read()
	assert_int(_state().address_book.entries.size()).is_equal(listed.size() + 1)
	assert_object(_state().address_book.find(known_key)).is_same(known)
	assert_int(known.source).is_equal(AddressEntry.Source.DOCUMENT)


## The read console and its entries survive a JSON round trip, and a loaded game refuses a
## second read.
func test_read_survives_save_and_load() -> void:
	var reader: StringName = _reader_id()
	_dial(reader)
	_read()
	var text: String = JSON.stringify(_state().to_dict())
	var data: Dictionary = JSON.parse_string(text)
	assert_array(GameState.validate_dict(data)).is_empty()
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var loaded: Simulation = GameSetup.build(GameState.from_dict(data), defs).value
	assert_bool(loaded.state.worlds.is_console_read(reader)).is_true()
	assert_dict(loaded.state.address_book.to_dict()).is_equal(_state().address_book.to_dict())
	var again: CommandResult = loaded.submit(ReadConsoleCommand.new())
	assert_str(String(again.error_code)).is_equal("console_already_read")
