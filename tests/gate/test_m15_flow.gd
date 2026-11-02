## M1.5 and M1.6 end to end, headless, over the real data/ content: a scripted player who knows
## the approved answers starts a new game, finds the opening documents in the Archive, cannot
## dial until the Capacitor Bank is built as a room, then enters SILL, LINTEL, MILESTONE and
## STILLWATER in turn by clicking the real dial console (click to fill, click a slot to remove)
## and dials them at 10×; each lock drops the clock to 1×. After each lock it extends the pole
## camera for the next documents (the lock alone delivers none), reads the console (2 to 4
## addresses) and closes the wormhole; then it dials console addresses the bank can power until
## one locks, and the operations log holds every step. A few other seeds check every new galaxy
## gives such an address; 2,000 random addresses give no lock.
## Bible: roadmap.md (M1.5 and M1.6 checks), technical-architecture.md#testing-and-tooling,
## gate-and-address-spec.md#where-addresses-come-from, game-design.md#time-real-time-with-pause,
## game-design.md#core-loop (Archive: the operations log)
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const CONSOLE_SCENE: String = "res://src/ui/gate_room/console/dial_console.tscn"
## The fastest clock speed (10×), at which every puzzle is dialed.
const FASTEST_SPEED: int = 3

## Seed of the played game.
const SEED: int = 20_261_024
## Seeds checked for a reachable, lockable console address after the four puzzles.
const OTHER_SEEDS: Array[int] = [1, 2, 3, 58, 1958, 1961, 424_242, 987_654_321]
## Random addresses dialed by resolution in the brute-force check, and their stream's seed.
const RANDOM_ADDRESSES: int = 2000
const RANDOM_SEED: int = 5858
## Most console addresses the player tries before the test gives up.
const MAX_CONSOLE_TRIES: int = 16

var _defs: GameDefs
var _console: DialConsole = null
var _real_locale: String = ""


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	if is_instance_valid(_console):
		_console.free()
	_console = null
	TranslationServer.set_locale(_real_locale)


func _new_player(base_seed: int) -> M15Player:
	var built: Result = GameSetup.build_new(GameState.new_game(base_seed, _defs.balance), _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var simulation: Simulation = built.value
	assert_bool(simulation.state.clock.is_paused).is_true()
	return M15Player.new(simulation)


## The whole M1.6 flow from a new game to a lock on a console address.
func test_new_game_to_console_lock() -> void:
	var player: M15Player = _new_player(SEED)
	_console = (load(CONSOLE_SCENE) as PackedScene).instantiate() as DialConsole
	var runner: GdUnitSceneRunner = scene_runner(_console)
	_console.setup(player.simulation)
	await runner.await_input_processed()
	_assert_start(player)
	_assert_no_dial_before_bank(player)
	for index: int in M15Player.PUZZLES.size():
		var glyphs: Array = M15Player.PUZZLES[index]["glyphs"]
		var entered: GateAddress = await _enter_by_clicks(glyphs)
		assert_str(entered.key()).is_equal(player.address(glyphs).key())
		_play_puzzle(player, index, entered)
	_assert_console_lock(player)
	_assert_log(player)
	assert_array(player.rejections).is_empty()


## Empties the console by clicking each filled slot (click to remove), then clicks
## [param glyphs] on the palette (click to fill, seals 1 to 7 in order); returns the console's
## address.
func _enter_by_clicks(glyphs: Array) -> GateAddress:
	var seals: SealRow = _console.get_node("%SealRow") as SealRow
	var palette: GlyphPalette = _console.get_node("%Palette") as GlyphPalette
	for seal: int in range(1, GateAddress.COORDINATE_COUNT + 1):
		if _console.get_placed(seal) >= 0:
			await UiInput.click(seals.get_slot(seal))
		assert_int(_console.get_placed(seal)).is_equal(-1)
	var typed: Array[int] = []
	typed.assign(glyphs)
	for glyph: int in typed:
		await UiInput.click(palette.get_button(glyph))
	return _console.get_address()


## A new game holds the two opening documents, unread, and an empty Address Book; nothing is
## locked.
func _assert_start(player: M15Player) -> void:
	var archive: ArchiveState = player.state().archive
	assert_array(archive.received).is_equal(M15Player.START_DOCUMENTS)
	for id: StringName in archive.received:
		assert_bool(archive.is_read(id)).is_false()
	assert_array(player.state().address_book.entries).is_empty()
	assert_dict(player.state().worlds.statuses).is_empty()


## Capacitor Bank is built as a room on the nearest valid spot to the Gate Room over its 360 build
## ticks, takes the spare supply the moment it is completed, and the answer can then be charged.
func _assert_no_dial_before_bank(player: M15Player) -> void:
	var sill_glyphs: Array = M15Player.PUZZLES[0]["glyphs"]
	var sill: GateAddress = player.address(sill_glyphs)
	var state: GameState = player.state()
	assert_float(PowerRules.capacity_mwh(state)).is_equal(0.0)
	_assert_dial_refused(player, sill)
	assert_int(GateQueries.ticks_until_ready(state, sill)).is_equal(-1)
	assert_bool(player.simulation.submit(PowerFixture.build_first_bank(state)).is_ok).is_true()
	var bank_def: RoomDef = state.room_defs[StartingBase.CAPACITOR_BANK_DEF]
	assert_int(bank_def.build_ticks).is_equal(360)
	for _tick: int in bank_def.build_ticks - 1:
		player.step()
	assert_bool(state.power.charge_rates.is_empty()).is_true()
	_assert_dial_refused(player, sill)
	player.step()
	assert_array(state.power.charge_rates.values()).is_equal([26])
	assert_float(PowerRules.allocated_mw(state)).is_equal(PowerRules.supply_mw(state))
	assert_int(GateQueries.ticks_until_ready(state, sill)).is_greater(0)
	player.rejections.clear()


func _assert_dial_refused(player: M15Player, target: GateAddress) -> void:
	var result: CommandResult = player.simulation.submit(DialCommand.create(target))
	assert_bool(result.is_ok).is_false()
	assert_str(String(result.error_code)).is_equal("insufficient_charge")
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.IDLE)


## Puzzle [param index]: charge, dial [param target] (the answer) at 10×, lock its world at 1×
## (nothing arrives yet), extend the pole camera and receive exactly the next documents (a
## second extension is already_taken), read the console (2 to 4 addresses, all now in the book)
## and close.
func _play_puzzle(player: M15Player, index: int, target: GateAddress) -> void:
	var puzzle: Dictionary = M15Player.PUZZLES[index]
	var world_id: StringName = puzzle["world"]
	var held_before: Array[StringName] = player.state().archive.received.duplicate()
	assert_bool(player.wait_for_charge(target)).override_failure_message(world_id).is_true()
	player.state().clock.speed_index = FASTEST_SPEED
	var entry: DialLogEntry = player.dial(target)
	assert_object(entry).override_failure_message(world_id).is_not_null()
	assert_int(entry.outcome).override_failure_message(world_id).is_equal(DialOutcome.Kind.LOCK)
	assert_str(String(entry.world_id)).is_equal(String(world_id))
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(player.state().clock.speed_index).is_equal(ClockState.NORMAL_SPEED_INDEX)
	assert_array(player.state().archive.received).is_equal(held_before)
	var arrived: Array[StringName] = player.extend_pole_camera()
	assert_bool(player.state().worlds.is_horizon_record_taken(world_id)).is_true()
	var again: CommandResult = ExtendPoleCameraCommand.new().validate(player.state())
	assert_str(String(again.error_code)).is_equal("already_taken")
	var delivers: Array = puzzle["delivers"]
	var expected: Array[StringName] = []
	expected.assign(delivers)
	assert_array(arrived).contains_exactly_in_any_order(expected)
	_assert_console(player, world_id, index == 0)
	assert_bool(player.close_wormhole()).is_true()
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.IDLE)


## Reads [param world_id]'s console: it lists 2 to 4 addresses and every one is in the book
## afterwards; on the first console (an otherwise empty book) each one is a new entry.
func _assert_console(player: M15Player, world_id: StringName, first: bool) -> void:
	var listed: Array[String] = ReadConsoleCommand.listed_keys(player.state(), world_id)
	assert_int(listed.size()).override_failure_message(world_id).is_between(2, 4)
	var added: Array[AddressEntry] = player.read_console()
	assert_bool(player.state().worlds.is_console_read(world_id)).is_true()
	for key: String in listed:
		assert_object(player.state().address_book.find(key)).is_not_null()
	for entry: AddressEntry in added:
		assert_int(entry.source).is_equal(AddressEntry.Source.CONSOLE)
		assert_str(String(entry.world_id)).is_empty()
	if first:
		assert_int(added.size()).is_equal(listed.size())


## Dials, in book order, the console addresses the bank can power until one locks: each true
## address answers with a Ring (never No gate or Origin rejected), and one of them opens.
func _assert_console_lock(player: M15Player) -> void:
	var candidates: Array[AddressEntry] = player.reachable_console_entries()
	assert_array(candidates).is_not_empty()
	var tries: int = 0
	for candidate: AddressEntry in candidates.slice(0, MAX_CONSOLE_TRIES):
		var target: GateAddress = M15Player.parse_key(candidate.address_key)
		assert_bool(player.wait_for_charge(target)).is_true()
		var entry: DialLogEntry = player.dial(target)
		assert_object(entry).is_not_null()
		tries += 1
		assert_int(entry.outcome).is_not_equal(DialOutcome.Kind.NO_GATE)
		assert_int(entry.outcome).is_not_equal(DialOutcome.Kind.ORIGIN_REJECTED)
		if DialOutcome.is_lock(entry.outcome):
			assert_str(String(candidate.world_id)).is_equal(String(entry.world_id))
			assert_bool(player.close_wormhole()).is_true()
			return
	fail("no console address locked in %d tries" % tries)


## The operations log after the flow: one power entry; a horizon record and a console read for
## each puzzle world, in play order; a document entry for every document that arrived; a dial
## entry per Dial Log entry; and a lock entry per lock (the four puzzles and the console lock).
func _assert_log(player: M15Player) -> void:
	var log_state: LogState = player.state().operations_log
	assert_int(_of_kind(log_state, &"power").size()).is_equal(1)
	var worlds: Array[StringName] = []
	for puzzle: Dictionary in M15Player.PUZZLES:
		worlds.append(puzzle["world"])
	assert_array(_worlds_of(_of_kind(log_state, &"horizon"))).is_equal(worlds)
	assert_array(_worlds_of(_of_kind(log_state, &"console"))).is_equal(worlds)
	var documents: Array[String] = []
	for entry: LogEntry in _of_kind(log_state, &"document"):
		var id: String = entry.args["document_id"]
		documents.append(id)
	for id: StringName in player.state().archive.received:
		if not M15Player.START_DOCUMENTS.has(id):
			assert_array(documents).contains([String(id)])
	var dials: int = player.state().gate.dial_log.size()
	assert_int(_of_kind(log_state, &"dial").size()).is_equal(dials)
	assert_int(_of_kind(log_state, &"lock").size()).is_equal(M15Player.PUZZLES.size() + 1)


## The entries of [param kind] in [param log_state], oldest first.
static func _of_kind(log_state: LogState, kind: StringName) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in log_state.entries:
		if entry.kind == kind:
			found.append(entry)
	return found


## The world of each of [param entries], in order.
static func _worlds_of(entries: Array[LogEntry]) -> Array[StringName]:
	var worlds: Array[StringName] = []
	for entry: LogEntry in entries:
		worlds.append(entry.world_id)
	return worlds


## On every seed, after the four puzzles the book holds a console address the bank can power
## whose Ring is open: a new player always has somewhere to go next.
func test_every_seed_has_a_reachable_console_address() -> void:
	for base_seed: int in OTHER_SEEDS:
		var state: GameState = _new_player(base_seed).state()
		var openable: int = 0
		var reachable: int = 0
		for key: String in _console_keys(state):
			var target: GateAddress = M15Player.parse_key(key)
			if (
				GateQueries.lock_energy_mwh(state, target)
				> _defs.balance.capacitor_bank_capacity_mwh
			):
				continue
			reachable += 1
			var answer: Dictionary = DialResolver.resolve(target, state.galaxy)
			var outcome: DialOutcome.Kind = answer["outcome"]
			if DialOutcome.is_lock(outcome):
				openable += 1
		(
			assert_int(openable)
			. override_failure_message("seed %d: %d reachable, none opens" % [base_seed, reachable])
			. is_greater(0)
		)


## Every address the four puzzle worlds' consoles list, without repeats.
func _console_keys(state: GameState) -> Array[String]:
	var keys: Array[String] = []
	for puzzle: Dictionary in M15Player.PUZZLES:
		var world_id: StringName = puzzle["world"]
		for key: String in ReadConsoleCommand.listed_keys(state, world_id):
			if not keys.has(key):
				keys.append(key)
	return keys


## Brute force fails: 2,000 random well-formed addresses from CAIRN, resolved against the
## played galaxy, open no wormhole.
func test_random_addresses_never_lock() -> void:
	var state: GameState = _new_player(SEED).state()
	var origin: int = state.galaxy.home().origin_glyph
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	var locks: Array[String] = []
	for _index: int in RANDOM_ADDRESSES:
		var target: GateAddress = _random_address(rng, origin)
		var answer: Dictionary = DialResolver.resolve(target, state.galaxy)
		var outcome: DialOutcome.Kind = answer["outcome"]
		if DialOutcome.is_lock(outcome):
			locks.append(target.key())
	assert_array(locks).is_empty()


## Seven distinct glyphs other than [param origin], then the origin.
static func _random_address(rng: RandomNumberGenerator, origin: int) -> GateAddress:
	var pool: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			pool.append(glyph)
	var coordinates: Array[int] = []
	while coordinates.size() < GateAddress.COORDINATE_COUNT:
		coordinates.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return GateAddress.create(coordinates, origin)
