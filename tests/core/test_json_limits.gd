## Tests for JsonLimits: the 2^53 constant, is_exact_int() at and around its boundaries,
## and a scan proving no other script under src/ keeps its own copy of the literal.
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system
extends GdUnitTestSuite

const SOURCE_ROOT: String = "res://src"
const OWNER_PATH: String = "res://src/core/json_limits.gd"
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
## The literal the scan looks for, built so this file does not contain it whole.
const LITERAL: String = "90071992" + "54740992"


## MAX_EXACT_INT is 2^53, and the float 2^53 converts to it exactly.
func test_max_exact_int_is_two_pow_53() -> void:
	assert_int(JsonLimits.MAX_EXACT_INT).is_equal(1 << 53)
	assert_str(str(JsonLimits.MAX_EXACT_INT)).is_equal(LITERAL)
	assert_int(int(float(JsonLimits.MAX_EXACT_INT))).is_equal(JsonLimits.MAX_EXACT_INT)


## Ints up to 2^53 in absolute value are exact; 2^53 + 1 and the int64 limits are not.
func test_is_exact_int_for_ints() -> void:
	var limit: int = JsonLimits.MAX_EXACT_INT
	for value: int in [0, 1, -1, limit, -limit, limit - 1]:
		assert_bool(JsonLimits.is_exact_int(value)).override_failure_message(str(value)).is_true()
	for value: int in [limit + 1, -limit - 1, 9223372036854775807, -9223372036854775807 - 1]:
		assert_bool(JsonLimits.is_exact_int(value)).override_failure_message(str(value)).is_false()


## Whole floats up to 2^53 in absolute value are exact; the next double above 2^53,
## fractions, NaN and infinities are not.
func test_is_exact_int_for_floats() -> void:
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	for value: float in [0.0, -0.0, 3.0, -3.0, limit, -limit]:
		assert_bool(JsonLimits.is_exact_int(value)).override_failure_message(str(value)).is_true()
	for value: float in [0.5, -1.5, limit + 2.0, -limit - 2.0, 1e300, INF, -INF, NAN]:
		assert_bool(JsonLimits.is_exact_int(value)).override_failure_message(str(value)).is_false()


## Values that are not numbers are never exact ints.
func test_is_exact_int_rejects_non_numbers() -> void:
	for value: Variant in [null, true, false, "1", &"1", [1], {"n": 1}, Vector2.ZERO]:
		assert_bool(JsonLimits.is_exact_int(value)).override_failure_message(str(value)).is_false()


## No script or resource under src/ other than json_limits.gd contains the 2^53 literal.
func test_no_other_copy_of_the_literal_in_src() -> void:
	var paths := _source_files(SOURCE_ROOT)
	assert_array(paths).contains([OWNER_PATH])
	for path: String in paths:
		if path == OWNER_PATH:
			continue
		var source := FileAccess.get_file_as_string(path)
		assert_bool(source.contains(LITERAL)).override_failure_message(path).is_false()


## Every file under [param dir], recursively, whose extension is in SCANNED_EXTENSIONS.
func _source_files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if SCANNED_EXTENSIONS.has(file_name.get_extension()):
			found.append(dir.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir):
		found.append_array(_source_files(dir.path_join(sub_dir)))
	return found
