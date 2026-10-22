## Tests for GateAddress: well-formedness edge cases, equality, the stable key, the dict round
## trip and validate_dict() errors for each malformed shape.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#data-model
extends GdUnitTestSuite

const COORDINATES: Array[int] = [3, 17, 0, 22, 9, 14, 30]
const ORIGIN: int = 5


func _sample() -> GateAddress:
	return GateAddress.create(COORDINATES, ORIGIN)


## The constants match the 8-seal structure: 7 coordinates + origin, 36 glyphs.
func test_constants() -> void:
	assert_int(GateAddress.COORDINATE_COUNT).is_equal(7)
	assert_int(GateAddress.GLYPH_COUNT).is_equal(36)
	assert_int(GateAddress.SEAL_COUNT).is_equal(8)


## create() copies its coordinates; seals() lists the coordinates then the origin.
func test_create_and_seals() -> void:
	var source: Array[int] = COORDINATES.duplicate()
	var address := GateAddress.create(source, ORIGIN)
	source[0] = 35
	assert_array(address.coordinates).is_equal(COORDINATES)
	assert_int(address.origin).is_equal(ORIGIN)
	assert_array(address.seals()).is_equal([3, 17, 0, 22, 9, 14, 30, 5])
	address.seals().append(1)
	assert_int(address.seals().size()).is_equal(8)


## A valid address is well formed, including the glyph bounds 0 and 35.
func test_well_formed() -> void:
	assert_bool(_sample().is_well_formed()).is_true()
	var bounds: Array[int] = [0, 35, 1, 2, 3, 4, 5]
	assert_bool(GateAddress.create(bounds, 34).is_well_formed()).is_true()


## Too few or too many coordinates are not well formed.
func test_wrong_count_is_not_well_formed() -> void:
	var short: Array[int] = [3, 17, 0, 22, 9, 14]
	var long: Array[int] = [3, 17, 0, 22, 9, 14, 30, 31]
	var empty: Array[int] = []
	assert_bool(GateAddress.create(short, ORIGIN).is_well_formed()).is_false()
	assert_bool(GateAddress.create(long, ORIGIN).is_well_formed()).is_false()
	assert_bool(GateAddress.create(empty, ORIGIN).is_well_formed()).is_false()


## A coordinate or origin outside 0..35 is not well formed.
func test_out_of_range_is_not_well_formed() -> void:
	var negative: Array[int] = [3, 17, -1, 22, 9, 14, 30]
	var high: Array[int] = [3, 17, 36, 22, 9, 14, 30]
	assert_bool(GateAddress.create(negative, ORIGIN).is_well_formed()).is_false()
	assert_bool(GateAddress.create(high, ORIGIN).is_well_formed()).is_false()
	assert_bool(GateAddress.create(COORDINATES, 36).is_well_formed()).is_false()
	assert_bool(GateAddress.create(COORDINATES, -1).is_well_formed()).is_false()


## A repeated coordinate, or the origin repeated among the coordinates, is not well formed.
func test_duplicates_are_not_well_formed() -> void:
	var repeated: Array[int] = [3, 17, 0, 22, 9, 3, 30]
	assert_bool(GateAddress.create(repeated, ORIGIN).is_well_formed()).is_false()
	assert_bool(GateAddress.create(COORDINATES, 22).is_well_formed()).is_false()


## equals() compares seals in order; null is never equal.
func test_equals() -> void:
	assert_bool(_sample().equals(_sample())).is_true()
	var swapped: Array[int] = [17, 3, 0, 22, 9, 14, 30]
	assert_bool(_sample().equals(GateAddress.create(swapped, ORIGIN))).is_false()
	assert_bool(_sample().equals(GateAddress.create(COORDINATES, 6))).is_false()
	assert_bool(_sample().equals(null)).is_false()


## key() joins the seals with "-", and is equal for equal addresses.
func test_key_is_stable() -> void:
	assert_str(_sample().key()).is_equal("3-17-0-22-9-14-30-5")
	assert_str(_sample().key()).is_equal(_sample().key())
	var other: Array[int] = [3, 17, 0, 22, 9, 14, 31]
	assert_str(GateAddress.create(other, ORIGIN).key()).is_not_equal(_sample().key())


## to_dict() then from_dict() gives an equal address, also after JSON turns ints to floats.
func test_dict_round_trip() -> void:
	var data: Dictionary = _sample().to_dict()
	assert_dict(data).is_equal({"seals": [3, 17, 0, 22, 9, 14, 30, 5]})
	assert_array(GateAddress.validate_dict(data)).is_empty()
	assert_bool(GateAddress.from_dict(data).equals(_sample())).is_true()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(GateAddress.validate_dict(parsed)).is_empty()
	var restored := GateAddress.from_dict(parsed)
	assert_bool(restored.equals(_sample())).is_true()
	assert_str(restored.key()).is_equal(_sample().key())


## from_dict() of unreadable data gives an empty, malformed address instead of failing.
func test_from_dict_of_bad_data_is_malformed() -> void:
	for data: Dictionary in [{}, {"seals": "1-2"}, {"seals": []}]:
		var address := GateAddress.from_dict(data)
		assert_array(address.coordinates).is_empty()
		assert_bool(address.is_well_formed()).is_false()


## validate_dict() reports a missing or non-array seal list.
func test_validate_dict_shape_errors() -> void:
	assert_array(GateAddress.validate_dict({})).is_equal(["missing 'seals'"])
	assert_array(GateAddress.validate_dict({"seals": 5})).is_equal(["'seals' is not an array"])


## validate_dict() reports a wrong seal count.
func test_validate_dict_wrong_count() -> void:
	var errors := GateAddress.validate_dict({"seals": [3, 17, 0, 22, 9, 14, 30]})
	assert_array(errors).is_equal(["'seals' has 7 seals, not 8"])
	errors = GateAddress.validate_dict({"seals": [3, 17, 0, 22, 9, 14, 30, 5, 6]})
	assert_array(errors).is_equal(["'seals' has 9 seals, not 8"])


## validate_dict() reports seals that are not whole numbers.
func test_validate_dict_not_whole() -> void:
	for bad: Variant in ["3", 2.5, null, true, NAN]:
		var errors := GateAddress.validate_dict({"seals": [3, 17, 0, 22, bad, 14, 30, 5]})
		assert_array(errors).override_failure_message(str(bad)).is_equal(
			["seal 5 is not a whole number"]
		)


## validate_dict() reports seals outside 0..35.
func test_validate_dict_out_of_range() -> void:
	var errors := GateAddress.validate_dict({"seals": [3, 17, 0, 22, 9, 14, 36, -1.0]})
	assert_array(errors).is_equal(
		["seal 7 is 36, not a glyph from 0 to 35", "seal 8 is -1, not a glyph from 0 to 35"]
	)


## validate_dict() reports a repeated coordinate and an origin repeated among the coordinates.
func test_validate_dict_duplicates() -> void:
	var errors := GateAddress.validate_dict({"seals": [3, 17, 0, 3.0, 9, 14, 30, 5]})
	assert_array(errors).is_equal(["seal 4 repeats glyph 3 from seal 1"])
	errors = GateAddress.validate_dict({"seals": [3, 17, 0, 22, 9, 14, 30, 22]})
	assert_array(errors).is_equal(["seal 8 repeats glyph 22 from seal 4"])
