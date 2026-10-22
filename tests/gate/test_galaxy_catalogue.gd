## Tests for GalaxyCatalogue over a generated fixture galaxy: lookups by id, the home world, and
## address lookups that agree with address_of() for every world and origin and miss on permuted,
## random or malformed addresses.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const Fixture := preload("res://tests/gate/galaxy_fixture.gd")
const SEED: int = 777
const RANDOM_SEED: int = 4040
const RANDOM_ADDRESSES: int = 2000

var _anchors: Array[Vector3i] = []
var _worlds: Array[WorldRecord] = []
var _catalogue: GalaxyCatalogue


func before() -> void:
	_anchors = Fixture.anchors()
	_worlds = WorldGenerator.generate(
		SEED, _anchors, Fixture.authored(_anchors), GeneratorParams.new(), BalanceConfig.new()
	)
	_catalogue = GalaxyCatalogue.build(_worlds, _anchors)


## Worlds are found by id in generation order; unknown ids give null.
func test_worlds_by_id_and_order() -> void:
	var all: Array[WorldRecord] = _catalogue.all_worlds()
	assert_int(all.size()).is_equal(_worlds.size())
	for index: int in all.size():
		assert_object(all[index]).is_same(_worlds[index])
		assert_object(_catalogue.get_world(_worlds[index].id)).is_same(_worlds[index])
	assert_object(_catalogue.get_world(&"world_9999")).is_null()
	assert_array(_catalogue.anchors_ly()).is_equal(_anchors)


## home() is the authored world with is_home; the fixture's origin is not among its seven
## nearest anchors.
func test_home() -> void:
	var home: WorldRecord = _catalogue.home()
	assert_str(String(home.id)).is_equal(String(Fixture.HOME_ID))
	assert_bool(home.is_home and home.is_authored).is_true()
	var nearest: Array[int] = AddressRule.nearest_anchors(home.position_ly, _anchors, -1, 7)
	assert_bool(nearest.has(home.origin_glyph)).is_false()


## address_of() follows the address rule; unknown worlds and bad origins give null.
func test_address_of() -> void:
	var record: WorldRecord = _worlds[5]
	var expected: GateAddress = AddressRule.address_of(record.position_ly, _anchors, 3)
	assert_bool(_catalogue.address_of(record.id, 3).equals(expected)).is_true()
	assert_object(_catalogue.address_of(&"nowhere", 3)).is_null()
	assert_object(_catalogue.address_of(record.id, -1)).is_null()
	assert_object(_catalogue.address_of(record.id, GateAddress.GLYPH_COUNT)).is_null()


## For every world and every origin, the address finds that world.
func test_find_agrees_with_address_of() -> void:
	var misses: Array[String] = []
	for origin: int in GateAddress.GLYPH_COUNT:
		for record: WorldRecord in _worlds:
			var address: GateAddress = _catalogue.address_of(record.id, origin)
			if _catalogue.find_by_coordinates(address.coordinates, origin) != record:
				misses.append("%s from %d" % [record.id, origin])
	assert_array(misses).is_empty()


## Reversed or rotated coordinates of a real address find nothing.
func test_permuted_address_finds_nothing() -> void:
	var hits: Array[String] = []
	for record: WorldRecord in _worlds:
		var address: GateAddress = _catalogue.address_of(record.id, record.origin_glyph)
		var reversed: Array[int] = address.coordinates.duplicate()
		reversed.reverse()
		var rotated: Array[int] = address.coordinates.slice(1)
		rotated.append(address.coordinates[0])
		for coordinates: Array[int] in [reversed, rotated]:
			if _catalogue.find_by_coordinates(coordinates, address.origin) != null:
				hits.append(str(coordinates))
	assert_array(hits).is_empty()


## Seeded random well-formed addresses find nothing (3.4e10 possibilities, about 300 worlds).
func test_random_address_finds_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	var hits: Array[String] = []
	for _sample: int in RANDOM_ADDRESSES:
		var glyphs: Array[int] = []
		while glyphs.size() < GateAddress.SEAL_COUNT:
			var glyph: int = rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
			if not glyphs.has(glyph):
				glyphs.append(glyph)
		var origin: int = glyphs.pop_back()
		if _catalogue.find_by_coordinates(glyphs, origin) != null:
			hits.append(str(glyphs))
	assert_array(hits).is_empty()


## Malformed input finds nothing: wrong coordinate count or an origin that is not a glyph.
func test_malformed_input_finds_nothing() -> void:
	var address: GateAddress = _catalogue.address_of(_worlds[1].id, 0)
	var short: Array[int] = address.coordinates.slice(0, 6)
	assert_object(_catalogue.find_by_coordinates(short, 0)).is_null()
	assert_object(_catalogue.find_by_coordinates(address.coordinates, -1)).is_null()
	assert_object(_catalogue.find_by_coordinates(address.coordinates, 36)).is_null()
