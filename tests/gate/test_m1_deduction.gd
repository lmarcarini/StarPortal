## The M1 milestone check, automated: a scripted player that reads only the delivered clues'
## constraints narrows each opening target to its candidates and dials them in order, waiting
## for charge with the real systems, until each target locks. And the converse: random
## dialing never finds a world (rule 5).
## Bible: roadmap.md (M1: a tester deduces three addresses from clues alone),
## gate-and-address-spec.md#puzzle-tuning-rules (2: last step by dialing; 5: brute force fails)
extends GdUnitTestSuite

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
## Most dials any target may take.
const MAX_DIALS: int = 3
## Every target must lock within the first 10 in-game days.
const DEADLINE_TICK: int = 10 * TimeMath.TICKS_PER_DAY
## Most candidates the player lists for a dossier.
const LIST_LIMIT: int = 20
const BRUTE_FORCE_DIALS: int = 2000
const BRUTE_FORCE_SEED: int = 31337

var _defs: GameDefs


## The scripted player. It sees the simulation only as a player would: the clues' dossier ids
## and constraints, the home Ring's origin glyph, the bank, the Ring's mode and the Dial Log's
## outcomes. It never reads a clue's target, the schedule or the galaxy's worlds.
class DeductionPlayer:
	extends RefCounted

	## Per dossier id worked: {"dials", "skipped", "candidates", "tick", "world_id"}.
	var solved: Dictionary[StringName, Dictionary] = {}
	var _simulation: Simulation

	func _init(simulation: Simulation) -> void:
		_simulation = simulation

	## Plays until [param deadline]: works each dossier in arrival order, waiting for the next
	## one when none is open. Returns when every dossier delivered so far is solved and
	## [param dossier_count] have been, or at the deadline.
	func play(dossier_count: int, deadline: int) -> void:
		while _simulation.state.clock.tick < deadline and solved.size() < dossier_count:
			var dossier_id: StringName = _next_open_dossier()
			if dossier_id.is_empty():
				_simulation.advance_tick()
				continue
			_solve(dossier_id, deadline)

	## The first dossier id received and not yet solved, or &"".
	func _next_open_dossier() -> StringName:
		for clue: ClueRecord in _simulation.state.intel.clues:
			if not solved.has(clue.dossier_id):
				return clue.dossier_id
		return &""

	## The constraints of every clue in [param dossier_id].
	func _constraints_of(dossier_id: StringName) -> Array[AddressConstraint]:
		var constraints: Array[AddressConstraint] = []
		for clue: ClueRecord in _simulation.state.intel.clues:
			if clue.dossier_id == dossier_id:
				constraints.append_array(clue.constraints)
		return constraints

	## Lists the dossier's candidates and dials them in order until one locks, skipping any
	## whose lock energy the bank can never hold (the Workbench shows it as never ready).
	func _solve(dossier_id: StringName, deadline: int) -> void:
		var origin: int = _simulation.state.galaxy.home().origin_glyph
		var constraints: Array[AddressConstraint] = _constraints_of(dossier_id)
		var count: int = CandidateCounter.count(constraints, origin)
		var candidates: Array[GateAddress] = CandidateCounter.list(constraints, origin, LIST_LIMIT)
		var record: Dictionary = {
			"dials": 0, "skipped": 0, "candidates": count, "tick": -1, "world_id": &""
		}
		solved[dossier_id] = record
		for address: GateAddress in candidates:
			if GateQueries.ticks_until_ready(_simulation.state, address) < 0:
				record["skipped"] += 1
				continue
			var entry: DialLogEntry = _dial(address, deadline)
			if entry == null:
				return
			record["dials"] += 1
			if DialOutcome.is_lock(entry.outcome):
				record["tick"] = entry.tick
				record["world_id"] = entry.world_id
				_close()
				return

	## Waits for the charge, dials [param address] and waits for the outcome; null when the
	## deadline comes first or the dial is refused.
	func _dial(address: GateAddress, deadline: int) -> DialLogEntry:
		var state: GameState = _simulation.state
		while state.power.stored_mwh < GateQueries.lock_energy_mwh(state, address):
			if state.clock.tick >= deadline:
				return null
			_simulation.advance_tick()
		if not _simulation.submit(DialCommand.create(address)).is_ok:
			return null
		var dialed: int = state.gate.dial_log.size()
		while state.gate.dial_log.size() == dialed:
			if state.clock.tick >= deadline:
				return null
			_simulation.advance_tick()
		return state.gate.dial_log[state.gate.dial_log.size() - 1]

	## Closes the open wormhole and lets the command apply.
	func _close() -> void:
		_simulation.submit(CloseWormholeCommand.new())
		_simulation.advance_tick()


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


## For seeds 1..10, every opening target locks within MAX_DIALS dials, all before the end of
## day 10, and the world locked is the one the dossier was about (checked by the test, not
## the player).
func test_scripted_player_deduces_every_target() -> void:
	for base_seed: int in SEEDS:
		var state: GameState = GameState.new_game(base_seed, _defs.balance)
		var built: Result = GameSetup.build_new(state, _defs)
		assert_bool(built.is_ok).is_true()
		var planned: Dictionary[StringName, int] = state.intel.scheduled_dossiers.duplicate()
		var simulation: Simulation = built.value
		var player := DeductionPlayer.new(simulation)
		player.play(planned.size(), DEADLINE_TICK)
		print("deduction seed %d: %s" % [base_seed, _report(player)])
		assert_int(player.solved.size()).is_equal(OpeningScenario.TARGET_COUNT)
		for dossier_id: StringName in player.solved:
			var record: Dictionary = player.solved[dossier_id]
			var where: String = "seed %d %s" % [base_seed, dossier_id]
			assert_int(record["dials"]).override_failure_message(where).is_between(1, MAX_DIALS)
			assert_int(record["tick"]).override_failure_message(where).is_between(0, DEADLINE_TICK)
			var world_id: StringName = record["world_id"]
			assert_str(String(world_id)).override_failure_message(where).is_not_empty()
			assert_bool(planned.has(world_id)).override_failure_message(where).is_true()
			assert_str(String(world_id)).is_equal(String(_target_of(state, dossier_id)))


## 2,000 random well-formed addresses from CAIRN's origin, resolved against a seeded galaxy,
## never lock. Prints how many of each outcome came back.
func test_brute_force_never_locks() -> void:
	var galaxy: GalaxyCatalogue = GameSetup.build_galaxy(BRUTE_FORCE_SEED, _defs)
	var origin: int = galaxy.home().origin_glyph
	var rng := RandomNumberGenerator.new()
	rng.seed = BRUTE_FORCE_SEED
	var counts: Dictionary[StringName, int] = {}
	for _dial: int in BRUTE_FORCE_DIALS:
		var address: GateAddress = random_address(rng, origin)
		assert_bool(address.is_well_formed()).is_true()
		var answer: Dictionary = DialResolver.resolve(address, galaxy)
		var outcome: DialOutcome.Kind = answer["outcome"]
		var key: StringName = DialOutcome.to_key(outcome)
		counts[key] = counts.get(key, 0) + 1
	print("brute force, %d dials: %s" % [BRUTE_FORCE_DIALS, counts])
	assert_int(counts.get(&"lock", 0)).is_equal(0)
	assert_int(counts.get(&"hostile_lock", 0)).is_equal(0)


## A random well-formed address: seven distinct glyphs other than [param origin], then it.
static func random_address(rng: RandomNumberGenerator, origin: int) -> GateAddress:
	var glyphs: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			glyphs.append(glyph)
	var coordinates: Array[int] = []
	for _seal: int in GateAddress.COORDINATE_COUNT:
		coordinates.append(glyphs.pop_at(rng.randi_range(0, glyphs.size() - 1)))
	return GateAddress.create(coordinates, origin)


## The checker's answer key: the target of [param dossier_id]'s clues.
func _target_of(state: GameState, dossier_id: StringName) -> StringName:
	for clue: ClueRecord in state.intel.clues:
		if clue.dossier_id == dossier_id:
			return clue.target_world_id
	return &""


func _report(player: DeductionPlayer) -> String:
	var parts: Array[String] = []
	for dossier_id: StringName in player.solved:
		var record: Dictionary = player.solved[dossier_id]
		var tick: int = record["tick"]
		var day: int = TimeMath.day_index(maxi(tick, 0)) + 1
		var line: String = "%s %d candidates (%d out of reach), %d dials, locked day %d"
		var values: Array = [dossier_id, record["candidates"], record["skipped"], record["dials"]]
		parts.append(line % (values + [day]))
	return "; ".join(parts)
