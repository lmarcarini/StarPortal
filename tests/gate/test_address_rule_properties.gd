## Property tests for AddressRule on a seeded random anchor set: addresses are well formed,
## deterministic, never use the origin as a coordinate, agree with a brute-force selection, and
## near positions share more leading seals than far ones.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math
extends GdUnitTestSuite

const SEED: int = 4242
const SAMPLES: int = 300
## Anchors and worlds sit within +/- this many light years per axis (a galaxy-sized box).
const SPREAD_LY: int = 50_000
const FAR_LY: int = 10_000

var _rng: RandomNumberGenerator
var _anchors: Array[Vector3i] = []


func before_test() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = SEED
	_anchors.clear()
	for _index: int in GateAddress.GLYPH_COUNT:
		_anchors.append(_random_position())


func _random_position() -> Vector3i:
	return Vector3i(
		_rng.randi_range(-SPREAD_LY, SPREAD_LY),
		_rng.randi_range(-SPREAD_LY, SPREAD_LY),
		_rng.randi_range(-SPREAD_LY, SPREAD_LY)
	)


func _random_origin() -> int:
	return _rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)


## Independent reference: repeatedly picks the unused anchor with the smallest
## (squared distance, index), computing distances with plain arithmetic.
func _brute_force(position: Vector3i, anchors: Array[Vector3i], origin: int) -> Array[int]:
	var picked: Array[int] = []
	while picked.size() < GateAddress.COORDINATE_COUNT:
		var best: int = -1
		var best_squared: int = 0
		for index: int in anchors.size():
			if index == origin or picked.has(index):
				continue
			var delta: Vector3i = anchors[index] - position
			var squared: int = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
			if best == -1 or squared < best_squared:
				best = index
				best_squared = squared
		picked.append(best)
	picked.append(origin)
	return picked


## Number of leading seals [param a] and [param b] share.
func _shared_prefix(a: GateAddress, b: GateAddress) -> int:
	var seals_a: Array[int] = a.seals()
	var seals_b: Array[int] = b.seals()
	var shared: int = 0
	while shared < seals_a.size() and seals_a[shared] == seals_b[shared]:
		shared += 1
	return shared


## Every address is well formed, ends in its origin, never uses the origin as a coordinate,
## comes out the same twice and matches the brute-force reference.
func test_addresses_are_well_formed_deterministic_and_correct() -> void:
	for _sample: int in SAMPLES:
		var position: Vector3i = _random_position()
		var origin: int = _random_origin()
		var address := AddressRule.address_of(position, _anchors, origin)
		assert_bool(address.is_well_formed()).is_true()
		assert_int(address.origin).is_equal(origin)
		assert_bool(address.coordinates.has(origin)).is_false()
		assert_bool(address.equals(AddressRule.address_of(position, _anchors, origin))).is_true()
		assert_array(address.seals()).is_equal(_brute_force(position, _anchors, origin))


## Positions at anchors, and between tied anchors, also match the brute-force reference.
func test_ties_match_brute_force() -> void:
	var tied: Array[Vector3i] = _anchors.duplicate()
	for index: int in range(1, tied.size(), 2):
		tied[index] = -tied[index - 1]
	for index: int in tied.size():
		for origin: int in [0, index, GateAddress.GLYPH_COUNT - 1]:
			var position: Vector3i = Vector3i.ZERO if index % 3 == 0 else tied[index]
			var address := AddressRule.address_of(position, tied, origin)
			assert_array(address.seals()).is_equal(_brute_force(position, tied, origin))


## Two positions 1 ly apart share at least as many leading seals, on average, as two
## positions 10,000 ly apart.
func test_neighbours_look_alike() -> void:
	var near_total: int = 0
	var far_total: int = 0
	var axes: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.UP, Vector3i.BACK]
	for _sample: int in SAMPLES:
		var position: Vector3i = _random_position()
		var origin: int = _random_origin()
		var axis: Vector3i = axes[_rng.randi_range(0, axes.size() - 1)]
		var address := AddressRule.address_of(position, _anchors, origin)
		var near := AddressRule.address_of(position + axis, _anchors, origin)
		var far := AddressRule.address_of(position + axis * FAR_LY, _anchors, origin)
		near_total += _shared_prefix(address, near)
		far_total += _shared_prefix(address, far)
	assert_int(near_total).is_greater_equal(far_total)
	assert_int(near_total).is_greater(far_total)
