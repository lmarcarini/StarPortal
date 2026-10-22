## Tests for ExactFloat: bit-exact round trips (signed zero, subnormals, extremes, random
## patterns), the fixed most-significant-first byte order, and rejection of bad strings and
## non-finite or negative values.
## Bible: technical-architecture.md#save-system (round-trip test)
extends GdUnitTestSuite


## The raw bytes of [param value], independent of ExactFloat.
func _bits(value: float) -> PackedByteArray:
	return PackedFloat64Array([value]).to_byte_array()


## A float with the given 64-bit pattern, from two 32-bit halves.
func _from_halves(high: int, low: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_u32(0, low)
	bytes.encode_u32(4, high)
	return bytes.decode_double(0)


func _assert_round_trip(value: float) -> void:
	var text := ExactFloat.encode(value)
	assert_bool(ExactFloat.is_encoded(text)).override_failure_message(text).is_true()
	var back := ExactFloat.decode(text)
	assert_bool(_bits(back) == _bits(value)).override_failure_message(text).is_true()


## Edge values come back bit for bit, including the sign of -0.0.
func test_edge_values_round_trip() -> void:
	var tiny := 1.0
	for _step: int in 300:
		tiny /= 10.0
	var values: Array[float] = [
		0.0,
		# -0.0, built from its bits: GDScript can drop the sign of a -0.0 literal in an array.
		_from_halves(0x80000000, 0),
		1.0 / 3.0,
		1.0 / 300.0,
		0.1 + 0.2,
		1e-300,
		tiny,
		# 5e-324, the smallest subnormal. Built from its bits: GDScript reads the literal
		# 5e-324 as 0.0.
		_from_halves(0, 1),
		1.7976931348623157e308,
		-1.7976931348623157e308,
		INF,
		-INF,
	]
	for value: float in values:
		_assert_round_trip(value)
	var negative_zero := _bits(ExactFloat.decode("8000000000000000"))
	assert_int(negative_zero[7]).is_equal(0x80)
	assert_bool(negative_zero == _bits(_from_halves(0x80000000, 0))).is_true()


## The encoding is the IEEE-754 pattern, most significant byte first, in lowercase.
func test_known_encodings() -> void:
	assert_str(ExactFloat.encode(1.0 / 3.0)).is_equal("3fd5555555555555")
	assert_str(ExactFloat.encode(1.0 / 300.0)).is_equal("3f6b4e81b4e81b4f")
	assert_str(ExactFloat.encode(400.0)).is_equal("4079000000000000")
	assert_str(ExactFloat.encode(0.0)).is_equal("0000000000000000")
	assert_str(ExactFloat.encode(_from_halves(0x80000000, 0))).is_equal("8000000000000000")
	assert_float(ExactFloat.decode("403e000000000000")).is_equal(30.0)
	assert_str(ExactFloat.encode(_from_halves(0, 1))).is_equal("0000000000000001")


## 10,000 random finite bit patterns from a seeded generator come back bit for bit.
func test_random_patterns_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var checked: int = 0
	while checked < 10000:
		var value := _from_halves(rng.randi(), rng.randi())
		if not is_finite(value):
			continue
		_assert_round_trip(value)
		checked += 1


## NaN encodes to a pattern that decodes to NaN.
func test_nan_stays_nan() -> void:
	assert_bool(is_nan(ExactFloat.decode(ExactFloat.encode(NAN)))).is_true()


## is_encoded() accepts exactly 16 lowercase hex digits; uppercase is rejected so every
## float has a single encoding.
func test_is_encoded_rejects_bad_values() -> void:
	assert_bool(ExactFloat.is_encoded("3fd5555555555555")).is_true()
	var bad: Array = [
		"3fd555555555555",
		"3fd55555555555555",
		"",
		"3FD5555555555555",
		"3fd555555555555g",
		"3fd55555 5555555",
		"0x3fd55555555555",
		"-3fd555555555555",
		0.5,
		1,
		null,
		true,
		["3fd5555555555555"],
		&"3fd5555555555555",
	]
	for value: Variant in bad:
		assert_bool(ExactFloat.is_encoded(value)).override_failure_message(str(value)).is_false()


## is_finite_non_negative() accepts encoded zero (either sign) and positive finite values,
## and rejects negatives, NaN, the infinities and anything not encoded.
func test_is_finite_non_negative() -> void:
	for value: float in [
		0.0, _from_halves(0x80000000, 0), _from_halves(0, 1), 1.0 / 300.0, 1.7976931348623157e308
	]:
		var text := ExactFloat.encode(value)
		(
			assert_bool(ExactFloat.is_finite_non_negative(text))
			. override_failure_message(text)
			. is_true()
		)
	for value: float in [-_from_halves(0, 1), -1.0, NAN, INF, -INF]:
		var text := ExactFloat.encode(value)
		(
			assert_bool(ExactFloat.is_finite_non_negative(text))
			. override_failure_message(text)
			. is_false()
		)
	for value: Variant in [1.0, 0, "3FD5555555555555", null]:
		var label := str(value)
		(
			assert_bool(ExactFloat.is_finite_non_negative(value))
			. override_failure_message(label)
			. is_false()
		)
