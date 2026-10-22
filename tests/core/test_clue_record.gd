## Tests for ClueRecord: the saved shape, JSON round trips and validate_dict() on kinds,
## grades, constraints, text arguments, image glyphs and ids.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## technical-architecture.md#data-model
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


## Asserts that [param data] with [param key] set to [param value] has an error containing
## [param expected].
func _assert_rejects(key: String, value: Variant, expected: String) -> void:
	var data := Fixture.fragment().to_dict()
	data[key] = value
	var errors := ClueRecord.validate_dict(data)
	var label := "%s = %s: %s" % [key, str(value), str(errors)]
	var found := errors.any(func(error: String) -> bool: return error.contains(expected))
	assert_bool(found).override_failure_message(label).is_true()


## The saved shape uses lowercase kind names, String ids and plain arrays.
func test_to_dict_shape() -> void:
	var data := Fixture.sky_chart().to_dict()
	assert_str(data["kind"]).is_equal("sky_chart")
	assert_str(data["id"]).is_equal("clue_0002")
	assert_int(typeof(data["id"])).is_equal(TYPE_STRING)
	assert_bool(data["is_true"]).is_true()
	assert_array(data["image_glyphs"]).is_equal([14, 3, 22, 7, 30, 1, 9])
	assert_dict(data["text_args"]).is_equal({"world": "P3X-118", "count": 7})
	assert_array(data["constraints"]).has_size(1)
	(
		assert_array(data.keys())
		. contains_exactly_in_any_order(
			[
				"id",
				"kind",
				"dossier_id",
				"target_world_id",
				"constraints",
				"is_true",
				"source_key",
				"grade",
				"text_key",
				"text_args",
				"image_glyphs",
				"received_tick",
			]
		)
	)


## Every kind saves under its name and reads back.
func test_every_kind_round_trips() -> void:
	for kind: int in ClueRecord.KIND_NAMES.size():
		var record := Fixture.fragment()
		record.kind = kind as ClueRecord.Kind
		var data := record.to_dict()
		assert_str(data["kind"]).is_equal(ClueRecord.KIND_NAMES[kind])
		assert_int(ClueRecord.from_dict(_json(data)).kind).is_equal(kind)
	assert_array(ClueRecord.KIND_NAMES).is_equal(
		["fragment", "pictorial", "sky_chart", "ordinal", "neighbour"]
	)


## A JSON round trip rebuilds an equal record with ints, not floats.
func test_json_round_trip() -> void:
	for record: ClueRecord in [Fixture.fragment(), Fixture.sky_chart()]:
		var data := record.to_dict()
		var parsed := _json(data)
		assert_array(ClueRecord.validate_dict(parsed)).is_empty()
		var restored := ClueRecord.from_dict(parsed)
		assert_dict(restored.to_dict()).is_equal(data)
		assert_int(typeof(restored.grade)).is_equal(TYPE_INT)
		assert_int(typeof(restored.received_tick)).is_equal(TYPE_INT)
		for name: Variant in restored.text_args:
			var arg: Variant = restored.text_args[name]
			assert_bool(arg is int or arg is String).is_true()
		assert_int(typeof(restored.id)).is_equal(TYPE_STRING_NAME)


## A planted clue keeps is_true = false.
func test_is_true_false_is_saved() -> void:
	var record := Fixture.fragment()
	record.is_true = false
	var restored := ClueRecord.from_dict(_json(record.to_dict()))
	assert_bool(restored.is_true).is_false()


## Unknown kinds, grades outside 0..4 and non-bool truth are rejected.
func test_rejects_bad_kind_grade_and_truth() -> void:
	for kind: Variant in ["cipher", "", 2, null, "FRAGMENT"]:
		_assert_rejects("kind", kind, "'kind'")
	for grade: Variant in [-1, 5, 1.5, "A", null]:
		_assert_rejects("grade", grade, "'grade'")
	_assert_rejects("is_true", 1, "'is_true'")


## Every id and key must be a non-empty string; the received tick a whole number 0..2^53.
func test_rejects_bad_ids_and_tick() -> void:
	for key: String in ["id", "dossier_id", "target_world_id", "source_key", "text_key"]:
		_assert_rejects(key, "", "'%s'" % key)
		_assert_rejects(key, 7, "'%s'" % key)
	for tick: Variant in [-1, 0.5, float(JsonLimits.MAX_EXACT_INT) * 2.0, "3"]:
		_assert_rejects("received_tick", tick, "'received_tick'")


## Constraints must be objects passing AddressConstraint.validate_dict().
func test_rejects_bad_constraints() -> void:
	_assert_rejects("constraints", {}, "'constraints' is not an array")
	_assert_rejects("constraints", [3], "constraint 0 is not an object")
	_assert_rejects("constraints", [{"kind": "glyph_at", "seal": 9, "glyphs": [1]}], "seal 9")
	_assert_rejects("constraints", [{"kind": "warp", "glyphs": [1]}], "unknown kind")


## Text args must be Strings or whole numbers; glyph and picture args glyph indices, seal
## and count args whole numbers, world and address args Strings.
func test_rejects_bad_text_args() -> void:
	_assert_rejects("text_args", [], "'text_args' is not an object")
	for bad: Variant in [1.5, true, null, [1], {"a": 1}, 1e300]:
		_assert_rejects("text_args", {"note": bad}, "text arg 'note'")
	for bad: Variant in [-1, 36, "Heron", 2.5]:
		_assert_rejects("text_args", {"glyph_a": bad}, "text arg 'glyph_a'")
		_assert_rejects("text_args", {"picture": bad}, "text arg 'picture'")
	_assert_rejects("text_args", {"seal_a": "two"}, "text arg 'seal_a'")
	_assert_rejects("text_args", {"count": "seven"}, "text arg 'count'")
	_assert_rejects("text_args", {"world": 3}, "text arg 'world'")
	_assert_rejects("text_args", {"address_a": 3}, "text arg 'address_a'")
	_assert_rejects("text_args", {"": 3}, "empty name")


## Whole floats (from JSON) and Strings are accepted as text args.
func test_accepts_json_text_args() -> void:
	var data := Fixture.fragment().to_dict()
	data["text_args"] = {"glyph_a": 35.0, "seal_a": 7.0, "label": "x", "n": -3.0, "world": ""}
	assert_array(ClueRecord.validate_dict(data)).is_empty()
	var restored := ClueRecord.from_dict(data)
	assert_dict(restored.text_args).is_equal(
		{"glyph_a": 35, "seal_a": 7, "label": "x", "n": -3, "world": ""}
	)


## Image glyphs must be glyph indices 0..35.
func test_rejects_unknown_image_glyphs() -> void:
	_assert_rejects("image_glyphs", {}, "'image_glyphs' is not an array")
	for bad: Variant in [-1, 36, 1.5, "3", null]:
		_assert_rejects("image_glyphs", [3, bad], "image glyph 1")
