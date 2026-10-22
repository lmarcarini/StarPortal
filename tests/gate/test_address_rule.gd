## Tests for AddressRule against a small hand-computed anchor set: distances, nearest anchors,
## ties broken by the lower glyph index, and an origin that would otherwise be a coordinate.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#determinism-and-numbers
extends GdUnitTestSuite

## Squared distances from (0, 0, 0): 0:0, 1:100, 2:400, 3:25, 4:900, 5:25, 6:25, 7:10000,
## 8:1600, 9:49. Nearest first: 0, 3, 5, 6 (a three-way tie), 9, 1, 2, 4, 8, 7.
## From (1, 0, 0): 0:1, 1:81, 2:401, 3:36, 4:901, 5:20, 6:26, 7:9801, 8:1601, 9:36.
## Nearest first: 0, 5, 6, 3, 9 (3 and 9 tie), 1, 2, 4, 8, 7.
const ANCHORS: Array[Vector3i] = [
	Vector3i(0, 0, 0),
	Vector3i(10, 0, 0),
	Vector3i(0, 20, 0),
	Vector3i(-5, 0, 0),
	Vector3i(0, 0, 30),
	Vector3i(3, 4, 0),
	Vector3i(0, -5, 0),
	Vector3i(100, 0, 0),
	Vector3i(0, 0, -40),
	Vector3i(7, 0, 0),
]


## squared_distance() is the exact integer sum of squares; distance_ly() its square root.
func test_distances() -> void:
	assert_int(AddressRule.squared_distance(Vector3i(1, 2, 3), Vector3i(4, 6, 3))).is_equal(25)
	assert_float(AddressRule.distance_ly(Vector3i(1, 2, 3), Vector3i(4, 6, 3))).is_equal(5.0)
	assert_float(AddressRule.distance_ly(Vector3i(6000, 8000, 0), Vector3i.ZERO)).is_equal(10000.0)


## At the coordinate bound the squared distance is exact: 3 * (2 * 10^6)^2.
func test_squared_distance_at_bounds_is_exact() -> void:
	var bound: int = AddressRule.MAX_COORDINATE_LY
	var corner := Vector3i(bound, bound, bound)
	var squared: int = AddressRule.squared_distance(corner, -corner)
	assert_int(squared).is_equal(12_000_000_000_000)
	assert_bool(AddressRule.is_within_bounds(corner)).is_true()
	assert_bool(AddressRule.is_within_bounds(-corner)).is_true()
	assert_bool(AddressRule.is_within_bounds(Vector3i(0, bound + 1, 0))).is_false()
	assert_bool(AddressRule.is_within_bounds(Vector3i(0, 0, -bound - 1))).is_false()


## nearest_anchors() orders by distance and breaks the three-way tie by the lower index.
func test_nearest_anchors_orders_ties_by_index() -> void:
	var all: Array[int] = AddressRule.nearest_anchors(Vector3i.ZERO, ANCHORS, -1, 10)
	assert_array(all).is_equal([0, 3, 5, 6, 9, 1, 2, 4, 8, 7])
	var first: Array[int] = AddressRule.nearest_anchors(Vector3i.ZERO, ANCHORS, -1, 3)
	assert_array(first).is_equal([0, 3, 5])


## nearest_anchors() skips the excluded index, returns all it has when count is too large,
## and nothing for count <= 0.
func test_nearest_anchors_edges() -> void:
	var skipped: Array[int] = AddressRule.nearest_anchors(Vector3i.ZERO, ANCHORS, 5, 4)
	assert_array(skipped).is_equal([0, 3, 6, 9])
	assert_int(AddressRule.nearest_anchors(Vector3i.ZERO, ANCHORS, 5, 20).size()).is_equal(9)
	assert_array(AddressRule.nearest_anchors(Vector3i.ZERO, ANCHORS, -1, 0)).is_empty()
	var none: Array[Vector3i] = []
	assert_array(AddressRule.nearest_anchors(Vector3i.ZERO, none, -1, 7)).is_empty()


## The origin far away: the seven nearest anchors, ties by index, then the origin.
func test_address_of_with_far_origin() -> void:
	var address := AddressRule.address_of(Vector3i.ZERO, ANCHORS, 7)
	assert_array(address.seals()).is_equal([0, 3, 5, 6, 9, 1, 2, 7])
	assert_bool(address.is_well_formed()).is_true()


## The origin would be among the nearest seven: it is skipped and the eighth nearest moves in.
func test_address_of_skips_near_origin() -> void:
	assert_array(AddressRule.address_of(Vector3i.ZERO, ANCHORS, 3).seals()).is_equal(
		[0, 5, 6, 9, 1, 2, 4, 3]
	)
	assert_array(AddressRule.address_of(Vector3i.ZERO, ANCHORS, 0).seals()).is_equal(
		[3, 5, 6, 9, 1, 2, 4, 0]
	)


## A tie between non-adjacent indices (3 and 9 from (1, 0, 0)) still orders by index.
func test_address_of_tie_away_from_anchor() -> void:
	var address := AddressRule.address_of(Vector3i(1, 0, 0), ANCHORS, 8)
	assert_array(address.seals()).is_equal([0, 5, 6, 3, 9, 1, 2, 8])


## The order of equal-distance anchors does not depend on where they sit in the input array:
## swapping two tied anchors' positions swaps their indices in the result.
func test_tie_break_follows_index_not_position() -> void:
	var swapped: Array[Vector3i] = ANCHORS.duplicate()
	swapped[3] = ANCHORS[6]
	swapped[6] = ANCHORS[3]
	var address := AddressRule.address_of(Vector3i.ZERO, swapped, 7)
	assert_array(address.seals()).is_equal([0, 3, 5, 6, 9, 1, 2, 7])


## With fewer than eight anchors the address cannot be well formed.
func test_address_of_too_few_anchors() -> void:
	var few: Array[Vector3i] = ANCHORS.slice(0, 7)
	var address := AddressRule.address_of(Vector3i.ZERO, few, 6)
	assert_int(address.coordinates.size()).is_equal(6)
	assert_bool(address.is_well_formed()).is_false()
