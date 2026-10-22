## Tests for WorkbenchState: defaults, the saved shape, JSON round trips and validate_dict()
## on the origin glyph and the constraints.
## Bible: gate-and-address-spec.md#player-tools, technical-architecture.md#data-model
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func _data() -> Dictionary:
	return Fixture.state().workbench.to_dict()


func _assert_has_error(data: Dictionary, expected: String) -> void:
	var errors := WorkbenchState.validate_dict(data)
	var found := errors.any(func(error: String) -> bool: return error.contains(expected))
	assert_bool(found).override_failure_message("%s: %s" % [expected, str(errors)]).is_true()


## A new draft uses the home Ring's origin (-1) and has no constraints.
func test_defaults() -> void:
	var workbench := WorkbenchState.new()
	assert_int(workbench.origin_glyph).is_equal(-1)
	assert_array(workbench.constraints).is_empty()
	assert_dict(workbench.to_dict()).is_equal({"origin_glyph": -1, "constraints": []})
	assert_int(WorkbenchState.MAX_CONSTRAINTS).is_equal(64)


## Five constraints and an origin survive a JSON round trip.
func test_json_round_trip() -> void:
	var data := _data()
	assert_array(data["constraints"]).has_size(5)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(WorkbenchState.validate_dict(parsed)).is_empty()
	var restored := WorkbenchState.from_dict(parsed)
	assert_dict(restored.to_dict()).is_equal(data)
	assert_int(typeof(restored.origin_glyph)).is_equal(TYPE_INT)
	for index: int in 5:
		assert_bool(restored.constraints[index].equals(Fixture.five_constraints()[index])).is_true()


## The origin glyph is -1..35, whole numbers only.
func test_origin_range() -> void:
	for good: Variant in [-1, 0, 35, 35.0, -1.0]:
		var data := _data()
		data["origin_glyph"] = good
		(
			assert_array(WorkbenchState.validate_dict(data))
			. override_failure_message(str(good))
			. is_empty()
		)
	for bad: Variant in [-2, 36, 1.5, "3", null]:
		var data := _data()
		data["origin_glyph"] = bad
		_assert_has_error(data, "'origin_glyph'")


## Up to 64 constraints are accepted; 65, malformed ones and non-arrays are rejected.
func test_constraint_limits() -> void:
	var data := _data()
	var many: Array = []
	for index: int in WorkbenchState.MAX_CONSTRAINTS:
		many.append(AddressConstraint.excluded(index % GateAddress.GLYPH_COUNT).to_dict())
	data["constraints"] = many
	assert_array(WorkbenchState.validate_dict(data)).is_empty()
	many.append(AddressConstraint.excluded(0).to_dict())
	_assert_has_error(data, "65 constraints, more than 64")
	data["constraints"] = [{"kind": "glyph_at", "seal": 0, "glyphs": [1]}]
	_assert_has_error(data, "constraint 0: seal")
	data["constraints"] = [{"kind": "exact_set", "glyphs": [1, 2]}]
	_assert_has_error(data, "constraint 0: 2 glyphs, not 7")
	data["constraints"] = ["x"]
	_assert_has_error(data, "constraint 0 is not an object")
	data["constraints"] = {}
	_assert_has_error(data, "'constraints' is not an array")
