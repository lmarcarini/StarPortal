## Tests for WorldGenerator on fixture anchors: deterministic from the seed, bounded and spaced
## placement, unique addresses from every origin, the early-reach guarantee, status and guard
## fractions, and generation time.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy, overview.md#locked-decisions
extends GdUnitTestSuite

const Fixture := preload("res://tests/gate/galaxy_fixture.gd")
const SEED: int = 31_337
const OTHER_SEED: int = 31_338
## Allowed gap between an actual share and its param, in fractions (3 percentage points).
const FRACTION_TOLERANCE: float = 0.03
const MAX_SECONDS: float = 2.0

var _anchors: Array[Vector3i] = []
var _authored: Array[WorldDef] = []
var _params: GeneratorParams
var _balance: BalanceConfig
var _worlds: Array[WorldRecord] = []


func before() -> void:
	_anchors = Fixture.anchors()
	_authored = Fixture.authored(_anchors)
	_params = GeneratorParams.new()
	_balance = BalanceConfig.new()
	_worlds = _generate(SEED)


func _generate(seed_value: int) -> Array[WorldRecord]:
	return WorldGenerator.generate(seed_value, _anchors, _authored, _params, _balance)


func _procedural() -> Array[WorldRecord]:
	return _worlds.filter(func(record: WorldRecord) -> bool: return not record.is_authored)


## Every field that defines a record, for comparing galaxies.
func _describe(worlds: Array[WorldRecord]) -> Array[String]:
	var lines: Array[String] = []
	for record: WorldRecord in worlds:
		lines.append(
			(
				"%s|%s|%s|%d|%d|%s"
				% [
					record.id,
					record.designation,
					record.position_ly,
					record.origin_glyph,
					record.ring_status,
					record.is_guarded
				]
			)
		)
	return lines


## The same seed and inputs give identical records; another seed gives another galaxy.
func test_generation_is_deterministic() -> void:
	assert_array(_describe(_generate(SEED))).is_equal(_describe(_worlds))
	var original: Array[String] = _describe(_worlds)
	var other: Array[String] = _describe(_generate(OTHER_SEED))
	assert_array(other).is_not_equal(original)
	var shared: int = 0
	for line: String in other:
		shared += 1 if original.has(line) else 0
	assert_int(shared).is_less(10)


## Authored worlds come first and keep their def; then world_count numbered procedural worlds.
func test_authored_first_then_numbered_worlds() -> void:
	assert_int(_worlds.size()).is_equal(_authored.size() + _params.world_count)
	var home: WorldRecord = _worlds[0]
	assert_str(String(home.id)).is_equal(String(Fixture.HOME_ID))
	assert_bool(home.is_authored and home.is_home).is_true()
	assert_str(home.designation).is_empty()
	assert_that(home.position_ly).is_equal(_authored[0].position_ly)
	var procedural: Array[WorldRecord] = _procedural()
	for index: int in procedural.size():
		var record: WorldRecord = procedural[index]
		assert_str(String(record.id)).is_equal("world_%04d" % (index + 1))
		assert_str(record.designation).is_equal("R-%04d" % (index + 1))
		assert_bool(record.is_home).is_false()
		assert_int(record.origin_glyph).is_between(0, GateAddress.GLYPH_COUNT - 1)


## Procedural worlds lie inside the bounds, at least min_spacing_ly from every other world and
## from every anchor (so none sits on an anchor).
func test_placement_is_bounded_and_spaced() -> void:
	var extents: Vector3i = _params.half_extents_ly
	var min_squared: int = _params.min_spacing_ly * _params.min_spacing_ly
	var problems: Array[String] = []
	for record: WorldRecord in _procedural():
		var position: Vector3i = record.position_ly
		if position.clamp(-extents, extents) != position:
			problems.append("%s out of bounds" % record.id)
		for anchor: Vector3i in _anchors:
			if AddressRule.squared_distance(position, anchor) < min_squared:
				problems.append("%s too near anchor %s" % [record.id, anchor])
		for other: WorldRecord in _worlds:
			if other != record:
				if AddressRule.squared_distance(position, other.position_ly) < min_squared:
					problems.append("%s too near %s" % [record.id, other.id])
	assert_array(problems).is_empty()


## From each of the 36 origins, no two worlds (authored included) share an address.
func test_addresses_unique_from_every_origin() -> void:
	for origin: int in GateAddress.GLYPH_COUNT:
		var keys: Dictionary[String, bool] = {}
		for record: WorldRecord in _worlds:
			keys[AddressRule.address_of(record.position_ly, _anchors, origin).key()] = true
		assert_int(keys.size()).override_failure_message("origin %d" % origin).is_equal(
			_worlds.size()
		)


## At least min_reach_worlds OPEN, unguarded procedural worlds can be locked from home within
## reach_energy_mwh.
func test_early_reach_guarantee() -> void:
	var home: WorldRecord = _worlds[0]
	var reachable: int = 0
	for record: WorldRecord in _procedural():
		if record.ring_status != WorldDef.RingStatus.OPEN or record.is_guarded:
			continue
		var address: GateAddress = AddressRule.address_of(
			record.position_ly, _anchors, home.origin_glyph
		)
		var energy: float = EnergyMath.lock_energy_mwh(
			address, home.position_ly, _anchors, _balance
		)
		reachable += 1 if energy <= _params.reach_energy_mwh else 0
	assert_int(reachable).is_greater_equal(_params.min_reach_worlds)


## Buried, shielded and guarded shares land within 3 percentage points of the params.
func test_status_and_guard_fractions() -> void:
	var procedural: Array[WorldRecord] = _procedural()
	var total: float = float(procedural.size())
	var buried: int = 0
	var shielded: int = 0
	var guarded: int = 0
	for record: WorldRecord in procedural:
		buried += 1 if record.ring_status == WorldDef.RingStatus.BURIED else 0
		shielded += 1 if record.ring_status == WorldDef.RingStatus.SHIELDED else 0
		guarded += 1 if record.is_guarded else 0
	var tolerance: float = FRACTION_TOLERANCE
	assert_float(buried / total).is_equal_approx(_params.buried_fraction, tolerance)
	assert_float(shielded / total).is_equal_approx(_params.shielded_fraction, tolerance)
	assert_float(guarded / total).is_equal_approx(_params.guarded_fraction, tolerance)


## Generation plus catalogue build stays well under two seconds; prints the time.
func test_generation_time() -> void:
	var started: int = Time.get_ticks_usec()
	var worlds: Array[WorldRecord] = _generate(SEED)
	var catalogue: GalaxyCatalogue = GalaxyCatalogue.build(worlds, _anchors)
	var seconds: float = (Time.get_ticks_usec() - started) / 1_000_000.0
	print("WorldGenerator: %d worlds generated and catalogued in %.3f s" % [worlds.size(), seconds])
	assert_int(catalogue.all_worlds().size()).is_equal(worlds.size())
	assert_float(seconds).is_less(MAX_SECONDS)
