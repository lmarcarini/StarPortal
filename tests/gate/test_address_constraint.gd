## Tests for AddressConstraint: the factories, well-formedness, the satisfaction table for every
## kind (NEARER_THAN with either or both glyphs absent), equality, the dict round trip and
## validate_dict() errors.
## Bible: gate-and-address-spec.md#clue-types-and-reliability
extends GdUnitTestSuite

## pos(3) = 1, pos(17) = 2, pos(0) = 3, pos(22) = 4, pos(9) = 5, pos(14) = 6, pos(30) = 7.
const COORDINATES: Array[int] = [3, 17, 0, 22, 9, 14, 30]
const ORIGIN: int = 5
const ABSENT_A: int = 1
const ABSENT_B: int = 2


func _address() -> GateAddress:
	return GateAddress.create(COORDINATES, ORIGIN)


func _fits(constraint: AddressConstraint) -> bool:
	return constraint.is_satisfied_by(_address())


func _one_of_each() -> Array[AddressConstraint]:
	return [
		AddressConstraint.glyph_at(2, 14),
		AddressConstraint.glyph_not_at(7, 3),
		AddressConstraint.excluded(35),
		AddressConstraint.included(0),
		AddressConstraint.exact_set(COORDINATES),
		AddressConstraint.nearer_than(9, 30),
	]


## The factories set kind, seal and glyphs; exact_set() stores a sorted copy.
func test_factories() -> void:
	var at := AddressConstraint.glyph_at(2, 14)
	assert_int(at.kind).is_equal(AddressConstraint.Kind.GLYPH_AT)
	assert_int(at.seal).is_equal(2)
	assert_array(at.glyphs).is_equal([14])
	var nearer := AddressConstraint.nearer_than(9, 30)
	assert_int(nearer.seal).is_equal(0)
	assert_array(nearer.glyphs).is_equal([9, 30])
	var source: Array[int] = COORDINATES.duplicate()
	var sky := AddressConstraint.exact_set(source)
	source[0] = 35
	assert_array(sky.glyphs).is_equal([0, 3, 9, 14, 17, 22, 30])


## One of each kind is well formed; bad seals, counts, ranges and repeats are not.
func test_well_formed() -> void:
	for constraint: AddressConstraint in _one_of_each():
		assert_bool(constraint.is_well_formed()).is_true()
	assert_bool(AddressConstraint.glyph_at(0, 1).is_well_formed()).is_false()
	assert_bool(AddressConstraint.glyph_not_at(8, 1).is_well_formed()).is_false()
	assert_bool(AddressConstraint.glyph_at(1, 36).is_well_formed()).is_false()
	assert_bool(AddressConstraint.excluded(-1).is_well_formed()).is_false()
	assert_bool(AddressConstraint.nearer_than(4, 4).is_well_formed()).is_false()
	var six: Array[int] = [0, 1, 2, 3, 4, 6]
	assert_bool(AddressConstraint.exact_set(six).is_well_formed()).is_false()
	var repeated: Array[int] = [0, 1, 2, 3, 4, 6, 6]
	assert_bool(AddressConstraint.exact_set(repeated).is_well_formed()).is_false()
	var sealed := AddressConstraint.included(4)
	sealed.seal = 3
	assert_bool(sealed.is_well_formed()).is_false()
	var unknown := AddressConstraint.included(4)
	unknown.kind = 9 as AddressConstraint.Kind
	assert_bool(unknown.is_well_formed()).is_false()


## GLYPH_AT / GLYPH_NOT_AT: pos(g) == seal / != seal; an absent glyph is at no seal.
func test_glyph_at_and_not_at() -> void:
	assert_bool(_fits(AddressConstraint.glyph_at(6, 14))).is_true()
	assert_bool(_fits(AddressConstraint.glyph_at(5, 14))).is_false()
	assert_bool(_fits(AddressConstraint.glyph_at(1, ABSENT_A))).is_false()
	assert_bool(_fits(AddressConstraint.glyph_at(1, ORIGIN))).is_false()
	assert_bool(_fits(AddressConstraint.glyph_not_at(6, 14))).is_false()
	assert_bool(_fits(AddressConstraint.glyph_not_at(5, 14))).is_true()
	assert_bool(_fits(AddressConstraint.glyph_not_at(1, ABSENT_A))).is_true()


## EXCLUDED / INCLUDED: absent / present at any seal; the origin is not a coordinate.
func test_excluded_and_included() -> void:
	assert_bool(_fits(AddressConstraint.excluded(ABSENT_A))).is_true()
	assert_bool(_fits(AddressConstraint.excluded(30))).is_false()
	assert_bool(_fits(AddressConstraint.excluded(ORIGIN))).is_true()
	assert_bool(_fits(AddressConstraint.included(30))).is_true()
	assert_bool(_fits(AddressConstraint.included(ABSENT_A))).is_false()
	assert_bool(_fits(AddressConstraint.included(ORIGIN))).is_false()


## EXACT_SET: the coordinates as a set, in any order; one glyph off fails.
func test_exact_set() -> void:
	var shuffled: Array[int] = [30, 14, 9, 22, 0, 17, 3]
	assert_bool(_fits(AddressConstraint.exact_set(shuffled))).is_true()
	var swapped: Array[int] = [30, 14, 9, 22, 0, 17, ABSENT_A]
	assert_bool(_fits(AddressConstraint.exact_set(swapped))).is_false()
	var with_origin: Array[int] = [30, 14, 9, 22, 0, 17, ORIGIN]
	assert_bool(_fits(AddressConstraint.exact_set(with_origin))).is_false()


## NEARER_THAN [a, b]: b absent, or a present and earlier.
func test_nearer_than() -> void:
	assert_bool(_fits(AddressConstraint.nearer_than(3, 30))).is_true()
	assert_bool(_fits(AddressConstraint.nearer_than(30, 3))).is_false()
	assert_bool(_fits(AddressConstraint.nearer_than(ABSENT_A, 30))).is_false()
	assert_bool(_fits(AddressConstraint.nearer_than(30, ABSENT_A))).is_true()
	assert_bool(_fits(AddressConstraint.nearer_than(ABSENT_A, ABSENT_B))).is_true()


## Wrong glyph counts and unknown kinds fit nothing; null addresses fit nothing.
func test_malformed_fits_nothing() -> void:
	var empty := AddressConstraint.excluded(ABSENT_A)
	empty.glyphs.clear()
	assert_bool(_fits(empty)).is_false()
	var three := AddressConstraint.nearer_than(3, 30)
	three.glyphs.append(9)
	assert_bool(_fits(three)).is_false()
	var unknown := AddressConstraint.included(3)
	unknown.kind = -1 as AddressConstraint.Kind
	assert_bool(_fits(unknown)).is_false()
	assert_bool(AddressConstraint.included(3).is_satisfied_by(null)).is_false()


## equals() compares kind, seal and glyphs; EXACT_SET glyphs in any order; null is never equal.
func test_equals() -> void:
	var each: Array[AddressConstraint] = _one_of_each()
	var again: Array[AddressConstraint] = _one_of_each()
	for index: int in each.size():
		for other: int in again.size():
			assert_bool(each[index].equals(again[other])).is_equal(index == other)
		assert_bool(each[index].equals(null)).is_false()
	(
		assert_bool(AddressConstraint.glyph_at(2, 14).equals(AddressConstraint.glyph_at(3, 14)))
		. is_false()
	)
	var reordered := AddressConstraint.exact_set(COORDINATES)
	reordered.glyphs.reverse()
	assert_bool(reordered.equals(AddressConstraint.exact_set(COORDINATES))).is_true()
	(
		assert_bool(
			AddressConstraint.nearer_than(3, 30).equals(AddressConstraint.nearer_than(30, 3))
		)
		. is_false()
	)


## to_dict() has the documented shape; every kind round-trips, also through JSON.
func test_dict_round_trip() -> void:
	assert_dict(AddressConstraint.glyph_at(2, 14).to_dict()).is_equal(
		{"kind": "glyph_at", "seal": 2, "glyphs": [14]}
	)
	assert_dict(AddressConstraint.included(4).to_dict()).is_equal(
		{"kind": "included", "glyphs": [4]}
	)
	for constraint: AddressConstraint in _one_of_each():
		var data: Dictionary = constraint.to_dict()
		assert_array(AddressConstraint.validate_dict(data)).is_empty()
		assert_bool(AddressConstraint.from_dict(data).equals(constraint)).is_true()
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
		assert_array(AddressConstraint.validate_dict(parsed)).is_empty()
		var loaded := AddressConstraint.from_dict(parsed)
		assert_bool(loaded.equals(constraint)).is_true()
		assert_bool(loaded.is_well_formed()).is_true()


## validate_dict() names each malformed shape.
func test_validate_dict_rejects() -> void:
	var cases: Array[Dictionary] = [
		{"glyphs": [1]},
		{"kind": "glyph_near", "glyphs": [1]},
		{"kind": 0, "glyphs": [1]},
		{"kind": "glyph_at", "glyphs": [1]},
		{"kind": "glyph_at", "seal": 0, "glyphs": [1]},
		{"kind": "glyph_not_at", "seal": 8, "glyphs": [1]},
		{"kind": "glyph_at", "seal": 2.5, "glyphs": [1]},
		{"kind": "included", "seal": 3, "glyphs": [1]},
		{"kind": "included", "glyphs": 1},
		{"kind": "included", "glyphs": []},
		{"kind": "nearer_than", "glyphs": [1]},
		{"kind": "exact_set", "glyphs": [0, 1, 2, 3, 4, 6]},
		{"kind": "excluded", "glyphs": [36]},
		{"kind": "excluded", "glyphs": [-1]},
		{"kind": "excluded", "glyphs": [1.5]},
		{"kind": "excluded", "glyphs": ["1"]},
		{"kind": "nearer_than", "glyphs": [4, 4.0]},
		{"kind": "exact_set", "glyphs": [0, 1, 2, 3, 4, 6, 0]},
	]
	for data: Dictionary in cases:
		(
			assert_array(AddressConstraint.validate_dict(data))
			. override_failure_message("accepted %s" % data)
			. is_not_empty()
		)
	var zero_seal: Dictionary = {"kind": "included", "seal": 0.0, "glyphs": [1.0]}
	assert_array(AddressConstraint.validate_dict(zero_seal)).is_empty()


## from_dict() on unreadable data gives a malformed constraint, never a crash.
func test_from_dict_unreadable() -> void:
	assert_bool(AddressConstraint.from_dict({}).is_well_formed()).is_false()
	var bad_glyphs: Dictionary = {"kind": "included", "glyphs": "x"}
	assert_bool(AddressConstraint.from_dict(bad_glyphs).is_well_formed()).is_false()
	var unknown: Dictionary = {"kind": "sideways", "glyphs": [1]}
	assert_int(AddressConstraint.from_dict(unknown).kind).is_equal(-1)
