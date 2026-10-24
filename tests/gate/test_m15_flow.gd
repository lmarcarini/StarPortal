## M1.5 end to end, headless, over the real data/ content: a scripted player who knows the
## approved answers starts a new game, finds the opening documents in the Archive, cannot dial
## until the capacitor bank is installed, then dials SILL, LINTEL, MILESTONE and STILLWATER in
## turn, each lock delivering the next documents, reads each console (2 to 4 addresses) and
## closes the wormhole; then it dials console addresses the bank can power until one locks. A
## few other seeds check every new galaxy gives such an address; 2,000 random addresses give
## no lock.
## Bible: roadmap.md (M1.5 check), technical-architecture.md#testing-and-tooling,
## gate-and-address-spec.md#where-addresses-come-from
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")

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


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _new_player(base_seed: int) -> M15Player:
	var built: Result = GameSetup.build_new(GameState.new_game(base_seed, _defs.balance), _defs)
	assert_bool(built.is_ok).override_failure_message(str(built.error_code)).is_true()
	var simulation: Simulation = built.value
	assert_bool(simulation.state.clock.is_paused).is_true()
	return M15Player.new(simulation)


## The whole M1.5 flow from a new game to a lock on a console address.
func test_new_game_to_console_lock() -> void:
	var player: M15Player = _new_player(SEED)
	_assert_start(player)
	_assert_no_dial_before_bank(player)
	for index: int in M15Player.PUZZLES.size():
		_play_puzzle(player, index)
	_assert_console_lock(player)
	assert_array(player.rejections).is_empty()


## A new game holds the two opening documents, unread, and an empty Address Book; nothing is
## locked.
func _assert_start(player: M15Player) -> void:
	var archive: ArchiveState = player.state().archive
	assert_array(archive.received).is_equal(M15Player.START_DOCUMENTS)
	for id: StringName in archive.received:
		assert_bool(archive.is_read(id)).is_false()
	assert_array(player.state().address_book.entries).is_empty()
	assert_dict(player.state().worlds.statuses).is_empty()


## Before the bank and while it installs, SILL's answer is refused for want of charge; the
## install takes the balance's 360 ticks, after which the answer can be charged.
func _assert_no_dial_before_bank(player: M15Player) -> void:
	var sill_glyphs: Array = M15Player.PUZZLES[0]["glyphs"]
	var sill: GateAddress = player.address(sill_glyphs)
	assert_float(player.state().power.capacity_mwh).is_equal(0.0)
	_assert_dial_refused(player, sill)
	assert_int(GateQueries.ticks_until_ready(player.state(), sill)).is_equal(-1)
	assert_bool(player.simulation.submit(InstallCapacitorsCommand.new()).is_ok).is_true()
	for _tick: int in _defs.balance.capacitor_bank_install_ticks - 1:
		player.step()
	assert_int(player.state().power.banks_installed).is_equal(0)
	_assert_dial_refused(player, sill)
	player.step()
	assert_int(player.state().power.banks_installed).is_equal(1)
	assert_int(_defs.balance.capacitor_bank_install_ticks).is_equal(360)
	assert_int(GateQueries.ticks_until_ready(player.state(), sill)).is_greater(0)
	player.rejections.clear()


func _assert_dial_refused(player: M15Player, target: GateAddress) -> void:
	var result: CommandResult = player.simulation.submit(DialCommand.create(target))
	assert_bool(result.is_ok).is_false()
	assert_str(String(result.error_code)).is_equal("insufficient_charge")
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.IDLE)


## Puzzle [param index]: charge, dial the answer, lock its world, receive exactly the next
## documents, read the console (2 to 4 addresses, all now in the book) and close.
func _play_puzzle(player: M15Player, index: int) -> void:
	var puzzle: Dictionary = M15Player.PUZZLES[index]
	var world_id: StringName = puzzle["world"]
	var glyphs: Array = puzzle["glyphs"]
	var target: GateAddress = player.address(glyphs)
	var held_before: Array[StringName] = player.state().archive.received.duplicate()
	assert_bool(player.wait_for_charge(target)).override_failure_message(world_id).is_true()
	var entry: DialLogEntry = player.dial(target)
	assert_object(entry).override_failure_message(world_id).is_not_null()
	assert_int(entry.outcome).override_failure_message(world_id).is_equal(DialOutcome.Kind.LOCK)
	assert_str(String(entry.world_id)).is_equal(String(world_id))
	assert_int(player.state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	var arrived: Array[StringName] = player.state().archive.received.slice(held_before.size())
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
