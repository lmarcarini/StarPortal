## Tests for OpeningScenario over the real data/ content: three targets meeting the product
## owner's ruling 1 (procedural, open, unguarded, dialable with the starting bank, distinct
## seal-1 glyphs), drawn deterministically from the &"scenario" stream, scheduled at the start
## of days 1 to 3 for a new game only.
## Bible: roadmap.md (M1 milestone check), gate-and-address-spec.md#puzzle-tuning-rules
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const GalaxyFixture := preload("res://tests/gate/galaxy_fixture.gd")
## Offsets of the _galaxy_near() worlds from their anchors, one direction each.
const _OFFSETS_LY: Array[Vector3i] = [
	Vector3i(800, 0, 0),
	Vector3i(0, 800, 0),
	Vector3i(-800, 0, 0),
	Vector3i(0, -800, 0),
	Vector3i(0, 0, 600),
	Vector3i(600, 600, 0),
]
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func _new_game(base_seed: int) -> GameState:
	var state: GameState = GameState.new_game(base_seed, _defs.balance)
	var built: Result = GameSetup.build_new(state, _defs)
	assert_bool(built.is_ok).is_true()
	return state


## For every seed, the three targets are procedural, OPEN, unguarded, dialable from home with
## a full starting bank and distinct, and use as many different seal-1 glyphs as the reachable
## worlds offer, up to three (with today's content only glyph 35 is reachable: one).
func test_targets_meet_ruling_one() -> void:
	for base_seed: int in SEEDS:
		var state: GameState = _new_game(base_seed)
		var targets: Array[StringName] = []
		targets.assign(state.intel.scheduled_dossiers.keys())
		assert_int(targets.size()).is_equal(OpeningScenario.TARGET_COUNT)
		var origin: int = state.galaxy.home().origin_glyph
		var first_glyphs: Dictionary[int, bool] = {}
		for id: StringName in targets:
			var world: WorldRecord = state.galaxy.get_world(id)
			assert_object(world).is_not_null()
			assert_bool(world.is_authored).is_false()
			assert_bool(world.is_guarded).is_false()
			assert_int(world.ring_status).is_equal(WorldDef.RingStatus.OPEN)
			var address: GateAddress = state.galaxy.address_of(id, origin)
			var energy: float = GateQueries.lock_energy_mwh(state, address)
			assert_float(energy).is_less_equal(_defs.balance.starting_capacity_mwh)
			first_glyphs[address.coordinates[0]] = true
		var reachable: int = _reachable_first_glyphs(state).size()
		assert_int(first_glyphs.size()).is_equal(mini(reachable, OpeningScenario.TARGET_COUNT))


## Seal-1 glyphs of every procedural, open, unguarded world dialable with a full bank.
func _reachable_first_glyphs(state: GameState) -> Dictionary[int, bool]:
	var glyphs: Dictionary[int, bool] = {}
	var origin: int = state.galaxy.home().origin_glyph
	for world: WorldRecord in state.galaxy.all_worlds():
		if world.is_authored or world.is_guarded or world.ring_status != WorldDef.RingStatus.OPEN:
			continue
		var address: GateAddress = state.galaxy.address_of(world.id, origin)
		if GateQueries.lock_energy_mwh(state, address) <= _defs.balance.starting_capacity_mwh:
			glyphs[address.coordinates[0]] = true
	return glyphs


## When several seal-1 glyphs are reachable, the picks all differ in seal 1, for any rng.
func test_prefers_different_first_glyphs() -> void:
	var galaxy: GalaxyCatalogue = _galaxy_near([2, 2, 2, 5, 5, 9])
	for seed_value: int in 20:
		var targets: Array[StringName] = _pick(galaxy, seed_value)
		assert_int(targets.size()).is_equal(3)
		var glyphs: Dictionary[int, bool] = {}
		for id: StringName in targets:
			glyphs[_first_glyph(galaxy, id)] = true
		assert_int(glyphs.size()).is_equal(3)


## With too few distinct glyphs, repeats fill the rest: two glyphs give three targets using
## both, and one glyph gives three targets sharing it.
func test_repeats_fill_when_glyphs_run_out() -> void:
	var two: GalaxyCatalogue = _galaxy_near([2, 2, 2, 5])
	var one: GalaxyCatalogue = _galaxy_near([2, 2, 2, 2])
	for seed_value: int in 20:
		var from_two: Array[StringName] = _pick(two, seed_value)
		assert_int(from_two.size()).is_equal(3)
		var glyphs: Dictionary[int, bool] = {}
		for id: StringName in from_two:
			glyphs[_first_glyph(two, id)] = true
		assert_int(glyphs.size()).is_equal(2)
		var from_one: Array[StringName] = _pick(one, seed_value)
		assert_int(from_one.size()).is_equal(3)
		assert_int(_first_glyph(one, from_one[0])).is_equal(_first_glyph(one, from_one[2]))


func _pick(galaxy: GalaxyCatalogue, seed_value: int) -> Array[StringName]:
	var balance := BalanceConfig.new()
	balance.starting_capacity_mwh = 100_000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return OpeningScenario.pick_targets(galaxy, balance, rng, OpeningScenario.TARGET_COUNT)


func _first_glyph(galaxy: GalaxyCatalogue, id: StringName) -> int:
	return galaxy.address_of(id, galaxy.home().origin_glyph).coordinates[0]


## A galaxy of the fixture home and one open, unguarded world next to each anchor listed
## (repeats allowed), each offset in its own direction so their addresses differ.
func _galaxy_near(anchor_glyphs: Array[int]) -> GalaxyCatalogue:
	var anchors: Array[Vector3i] = GalaxyFixture.anchors()
	var home_def: WorldDef = GalaxyFixture.home(anchors)
	var worlds: Array[WorldRecord] = [WorldRecord.from_def(home_def)]
	for index: int in anchor_glyphs.size():
		var record := WorldRecord.new()
		record.id = StringName("world_near_%d" % index)
		record.position_ly = anchors[anchor_glyphs[index]] + _OFFSETS_LY[index]
		worlds.append(record)
	return GalaxyCatalogue.build(worlds, anchors)


## Dossiers are due at the start of days 1, 2 and 3: ticks 0, 1440 and 2880.
func test_plan_schedules_days_one_to_three() -> void:
	var state: GameState = _new_game(SEEDS[0])
	var ticks: Array[int] = []
	ticks.assign(state.intel.scheduled_dossiers.values())
	ticks.sort()
	assert_array(ticks).is_equal([0, TimeMath.TICKS_PER_DAY, 2 * TimeMath.TICKS_PER_DAY])


## The same seed picks the same targets on the same days; another seed picks others.
func test_plan_is_deterministic() -> void:
	var first: GameState = _new_game(SEEDS[0])
	var again: GameState = _new_game(SEEDS[0])
	var other: GameState = _new_game(SEEDS[1])
	assert_dict(again.intel.scheduled_dossiers).is_equal(first.intel.scheduled_dossiers)
	assert_dict(other.intel.scheduled_dossiers).is_not_equal(first.intel.scheduled_dossiers)


## The draw uses the &"scenario" stream only: it moves that stream and no other.
func test_plan_draws_from_the_scenario_stream() -> void:
	var state: GameState = GameState.new_game(SEEDS[0], _defs.balance)
	GameSetup.build(state, _defs)
	var untouched: int = state.random.stream(&"intel").state
	var before_state: int = state.random.stream(OpeningScenario.STREAM_ID).state
	OpeningScenario.plan(state)
	assert_int(state.random.stream(OpeningScenario.STREAM_ID).state).is_not_equal(before_state)
	assert_int(state.random.stream(&"intel").state).is_equal(untouched)


## GameSetup.build(), the load path, never plans: a loaded game keeps its saved schedule.
func test_build_alone_never_plans() -> void:
	var state: GameState = GameState.new_game(SEEDS[0], _defs.balance)
	assert_bool(GameSetup.build(state, _defs).is_ok).is_true()
	assert_dict(state.intel.scheduled_dossiers).is_empty()
	var saved: GameState = _new_game(SEEDS[0])
	saved.intel.scheduled_dossiers.erase(saved.intel.scheduled_dossiers.keys()[0])
	var loaded: GameState = GameState.from_dict(saved.to_dict())
	assert_bool(GameSetup.build(loaded, _defs).is_ok).is_true()
	assert_dict(loaded.intel.scheduled_dossiers).is_equal(saved.intel.scheduled_dossiers)


## A galaxy with fewer eligible worlds gives fewer targets: the dial fixture has one open,
## unguarded world, so asking for three returns just it.
func test_fewer_targets_when_few_worlds_qualify() -> void:
	var galaxy: GalaxyCatalogue = DialFixture.galaxy()
	var balance := BalanceConfig.new()
	balance.starting_capacity_mwh = 100_000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var targets: Array[StringName] = OpeningScenario.pick_targets(galaxy, balance, rng, 3)
	assert_array(targets).is_equal([DialFixture.OPEN_ID])


## Opening dossiers leave at most three candidates (rule 2).
func test_clue_params_follow_rule_two() -> void:
	var params: ClueSetParams = OpeningScenario.clue_params()
	assert_int(params.max_candidates).is_equal(3)
	assert_int(params.min_candidates).is_equal(1)
