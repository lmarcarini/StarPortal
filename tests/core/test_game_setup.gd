## Tests for GameDefs and GameSetup: gathering the real data/ content from the Registry,
## building a Simulation with PowerSystem then GateSystem, regenerating the same
## galaxy after a JSON round trip, the transient balance and galaxy never being saved, and the
## failures.
## Bible: technical-architecture.md#simulation-clock-and-commands,
## technical-architecture.md#save-system, technical-architecture.md#data-model
extends GdUnitTestSuite

const GalaxyFixture := preload("res://tests/gate/galaxy_fixture.gd")
const SEED: int = 4242


func _defs() -> GameDefs:
	return GameDefs.from_registry(Registry)


## from_registry() gathers the balance, the 36 home anchors and CAIRN from data/.
func test_defs_from_the_registry() -> void:
	var defs: GameDefs = _defs()
	assert_object(defs.balance).is_same(Registry.balance())
	assert_int(defs.anchors.positions_ly.size()).is_equal(GateAddress.GLYPH_COUNT)
	assert_str(String(defs.anchors.id)).is_equal("anchors_home")
	var homes: Array[WorldDef] = defs.authored_worlds.filter(
		func(def: WorldDef) -> bool: return def.is_home
	)
	assert_int(homes.size()).is_equal(1)
	assert_str(String(homes[0].id)).is_equal("world_cairn")


## build() sets the transient references and ticks PowerSystem, then GateSystem.
func test_build_from_real_content_runs_both_systems() -> void:
	var defs: GameDefs = _defs()
	var state: GameState = GameState.new_game(SEED, defs.balance)
	state.power.banks_installed = 1
	state.power.capacity_mwh = defs.balance.capacitor_bank_capacity_mwh
	var result: Result = GameSetup.build(state, defs)
	assert_bool(result.is_ok).is_true()
	var simulation: Simulation = result.value
	assert_object(simulation.state).is_same(state)
	assert_object(state.balance).is_same(defs.balance)
	assert_str(String(state.galaxy.home().id)).is_equal("world_cairn")
	var ids: Array[StringName] = []
	for system: SimSystem in simulation._systems:
		ids.append(system.get_id())
	assert_array(ids).is_equal([&"power", &"gate", &"documents", &"economy", &"construction"])
	for index: int in 60:
		simulation.advance_tick()
	assert_float(state.power.stored_mwh).is_equal_approx(30.0, 1e-9)


## A state rebuilt from its JSON round-tripped to_dict() gets the same galaxy: every world
## is found at the same address.
func test_round_trip_rebuilds_the_same_galaxy() -> void:
	var defs: GameDefs = _defs()
	var original: GameState = GameState.new_game(SEED, defs.balance)
	GameSetup.build(original, defs)
	var data: Dictionary = JSON.parse_string(JSON.stringify(original.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	assert_object(loaded.galaxy).is_null()
	assert_bool(GameSetup.build(loaded, defs).is_ok).is_true()
	var origin: int = original.galaxy.home().origin_glyph
	var worlds: Array[WorldRecord] = original.galaxy.all_worlds()
	assert_int(loaded.galaxy.all_worlds().size()).is_equal(worlds.size())
	for world: WorldRecord in worlds:
		var address: GateAddress = original.galaxy.address_of(world.id, origin)
		var found: WorldRecord = loaded.galaxy.find_by_coordinates(address.coordinates, origin)
		assert_str(String(found.id)).is_equal(String(world.id))
		assert_int(found.ring_status).is_equal(world.ring_status)
		assert_bool(found.is_guarded).is_equal(world.is_guarded)


## The transient balance and galaxy never reach to_dict() or its JSON.
func test_transient_references_are_never_saved() -> void:
	var defs: GameDefs = _defs()
	var state: GameState = GameState.new_game(SEED, defs.balance)
	GameSetup.build(state, defs)
	var data: Dictionary = state.to_dict()
	assert_array(data.keys()).is_equal(
		[
			"clock",
			"random",
			"flags",
			"gate",
			"power",
			"budget",
			"base",
			"worlds",
			"archive",
			"address_book",
			"operations_log"
		]
	)
	var text: String = JSON.stringify(data)
	for word: String in ['galaxy"', "balance", "world_cairn", "anchors"]:
		assert_bool(text.contains(word)).override_failure_message(word).is_false()


## A save from another generator version fails and leaves the state untouched.
func test_generator_version_mismatch_fails() -> void:
	var defs: GameDefs = _defs()
	var state: GameState = GameState.new_game(SEED, defs.balance)
	state.worlds.generator_version = WorldGenerator.GENERATOR_VERSION + 1
	var result: Result = GameSetup.build(state, defs)
	assert_str(String(result.error_code)).is_equal("galaxy_version_mismatch")
	assert_object(state.balance).is_null()
	assert_object(state.galaxy).is_null()


## Missing content fails with &"missing_content".
func test_missing_content_fails() -> void:
	var state: GameState = GameState.new_game(SEED)
	assert_str(String(GameSetup.build(state, null).error_code)).is_equal("missing_content")
	var no_home: GameDefs = _defs()
	no_home.authored_worlds = []
	assert_str(String(GameSetup.build(state, no_home).error_code)).is_equal("missing_content")
	var no_anchors: GameDefs = _defs()
	no_anchors.anchors = null
	assert_str(String(GameSetup.build(state, no_anchors).error_code)).is_equal("missing_content")
	assert_object(state.galaxy).is_null()


## Hand-built defs from the test fixtures work the same way, without data/.
func test_build_from_hand_made_defs() -> void:
	var defs := GameDefs.new()
	defs.balance = BalanceConfig.new()
	defs.anchors = AnchorFieldDef.new()
	defs.anchors.positions_ly = GalaxyFixture.anchors()
	defs.authored_worlds = GalaxyFixture.authored(defs.anchors.positions_ly)
	var state: GameState = GameState.new_game(SEED, defs.balance)
	assert_bool(GameSetup.build(state, defs).is_ok).is_true()
	assert_str(String(state.galaxy.home().id)).is_equal(String(GalaxyFixture.HOME_ID))
