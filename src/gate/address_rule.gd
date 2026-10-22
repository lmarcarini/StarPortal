class_name AddressRule
extends RefCounted
## The address rule: a world's address from a Ring with origin glyph o is the seven anchors
## nearest to the world, excluding o, nearest first, then o. Pure static functions over integer
## light-year positions; no content, autoloads or randomness.
##
## Ordering uses the exact integer squared distance, so it never depends on float rounding;
## equal distances break by the lower glyph index. Every coordinate must lie within
## +/- MAX_COORDINATE_LY: then a squared distance is at most 3 * (2 * 10^6)^2 = 1.2 * 10^13,
## far inside int64 (and even inside a double's exact range, 2^53).
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#determinism-and-numbers

## Largest absolute value of a position coordinate, in light years. The galaxy is about
## 10^5 ly across, so this leaves a wide margin while keeping squared distances exact.
const MAX_COORDINATE_LY: int = 1_000_000


## Returns the exact squared distance between [param a] and [param b], in square light years.
## Both must lie within +/- MAX_COORDINATE_LY on every axis (asserted).
static func squared_distance(a: Vector3i, b: Vector3i) -> int:
	assert(is_within_bounds(a) and is_within_bounds(b), "AddressRule: position out of bounds")
	var delta: Vector3i = a - b
	return delta.x * delta.x + delta.y * delta.y + delta.z * delta.z


## Returns the distance between [param a] and [param b] in light years, for display and energy;
## never use it for ordering (use squared_distance()).
static func distance_ly(a: Vector3i, b: Vector3i) -> float:
	return sqrt(float(squared_distance(a, b)))


## True when every coordinate of [param position_ly] is within +/- MAX_COORDINATE_LY.
static func is_within_bounds(position_ly: Vector3i) -> bool:
	var largest: int = maxi(absi(position_ly.x), maxi(absi(position_ly.y), absi(position_ly.z)))
	return largest <= MAX_COORDINATE_LY


## Returns the indices of the [param count] anchors nearest to [param position_ly], nearest
## first, skipping index [param excluded] (pass -1 to skip none). Equal distances order by the
## lower index. Returns fewer when there are not enough anchors; empty when count <= 0.
static func nearest_anchors(
	position_ly: Vector3i, anchors_ly: Array[Vector3i], excluded: int, count: int
) -> Array[int]:
	var nearest: Array[int] = []
	if count <= 0:
		return nearest
	var distances: Array[int] = []
	for index: int in anchors_ly.size():
		distances.append(squared_distance(position_ly, anchors_ly[index]))
		if index != excluded:
			nearest.append(index)
	nearest.sort_custom(
		func(left: int, right: int) -> bool:
			if distances[left] != distances[right]:
				return distances[left] < distances[right]
			return left < right
	)
	return nearest.slice(0, count)


## Returns the 8-seal address of a Ring at [param position_ly] dialed from a Ring with origin
## glyph [param origin]: its seven nearest anchors other than the origin, nearest first, then
## the origin. [param anchors_ly] is indexed by glyph. With fewer than eight anchors, or an
## origin outside them, the address is not well formed.
static func address_of(
	position_ly: Vector3i, anchors_ly: Array[Vector3i], origin: int
) -> GateAddress:
	var coordinates: Array[int] = nearest_anchors(
		position_ly, anchors_ly, origin, GateAddress.COORDINATE_COUNT
	)
	return GateAddress.create(coordinates, origin)
