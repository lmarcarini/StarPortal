## Tests for DialOutcome: stable keys, their round trip, unknown keys and which kinds lock.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite


## Each kind has its stable key, and from_key() returns the kind for it.
func test_keys_round_trip() -> void:
	var expected: Dictionary[DialOutcome.Kind, StringName] = {
		DialOutcome.Kind.NO_GATE: &"no_gate",
		DialOutcome.Kind.BLOCKED: &"blocked",
		DialOutcome.Kind.ORIGIN_REJECTED: &"origin_rejected",
		DialOutcome.Kind.LOCK: &"lock",
		DialOutcome.Kind.HOSTILE_LOCK: &"hostile_lock",
	}
	assert_int(expected.size()).is_equal(DialOutcome.Kind.size())
	for kind: DialOutcome.Kind in expected:
		assert_that(DialOutcome.to_key(kind)).is_equal(expected[kind])
		assert_int(DialOutcome.from_key(expected[kind])).is_equal(kind)


## An unknown or empty key gives -1.
func test_unknown_key() -> void:
	assert_int(DialOutcome.from_key(&"open")).is_equal(-1)
	assert_int(DialOutcome.from_key(&"")).is_equal(-1)
	assert_int(DialOutcome.from_key(&"LOCK")).is_equal(-1)


## Only LOCK and HOSTILE_LOCK open a wormhole.
func test_is_lock() -> void:
	assert_bool(DialOutcome.is_lock(DialOutcome.Kind.LOCK)).is_true()
	assert_bool(DialOutcome.is_lock(DialOutcome.Kind.HOSTILE_LOCK)).is_true()
	assert_bool(DialOutcome.is_lock(DialOutcome.Kind.NO_GATE)).is_false()
	assert_bool(DialOutcome.is_lock(DialOutcome.Kind.BLOCKED)).is_false()
	assert_bool(DialOutcome.is_lock(DialOutcome.Kind.ORIGIN_REJECTED)).is_false()
