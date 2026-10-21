## Tests for RandomState: seed derivation, per-system streams, exact save and load of
## 64-bit seeds and states, and a scan of src/ for global randomness.
## Bible: technical-architecture.md#simulation-clock-and-commands (Randomness),
## technical-architecture.md#code-standards (Determinism and numbers)
extends GdUnitTestSuite

## 2^53 + 1: the smallest positive integer a JSON number (double) cannot hold exactly.
const ABOVE_2_POW_53: int = 9007199254740993
const SYSTEM_IDS: Array[StringName] = [&"expedition", &"research", &"glyphs", &"événement"]
## A call to a global random function: not preceded by a word character or a dot.
const GLOBAL_RANDOM_NAMES: String = "randi|randf|randi_range|randf_range|randfn|randomize"
const GLOBAL_RANDOM_PATTERN: String = "(?<![\\w.])(" + GLOBAL_RANDOM_NAMES + ")\\s*\\("


func _state_with_seed(from_seed: int) -> RandomState:
	var random := RandomState.new()
	random.base_seed = from_seed
	return random


func _json_round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


func _draw(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.randi())
	return values


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))


func _global_random_calls(source: String) -> Array[String]:
	var regex := RegEx.create_from_string(GLOBAL_RANDOM_PATTERN)
	var hits: Array[String] = []
	var lines := source.split("\n")
	for i: int in lines.size():
		var code := lines[i].get_slice("#", 0)
		if regex.search(code) != null:
			hits.append("%d: %s" % [i + 1, lines[i].strip_edges()])
	return hits


## FNV-1a 64 matches the published test vectors (as signed two's complement ints):
## "" = 0xcbf29ce484222325, "a" = 0xaf63dc4c8601ec8c, "foobar" = 0x85944171f73967e8.
func test_fnv1a_64_known_vectors() -> void:
	assert_int(RandomState.fnv1a_64(PackedByteArray())).is_equal(-3750763034362895579)
	assert_int(RandomState.fnv1a_64("a".to_utf8_buffer())).is_equal(-5808556873153909620)
	assert_int(RandomState.fnv1a_64("foobar".to_utf8_buffer())).is_equal(-8821353812377114648)


## derive_seed() is a pure function of the base seed and the id.
func test_derive_seed_is_deterministic() -> void:
	var first := RandomState.derive_seed(ABOVE_2_POW_53, &"research")
	assert_int(RandomState.derive_seed(ABOVE_2_POW_53, &"research")).is_equal(first)
	assert_int(RandomState.derive_seed(ABOVE_2_POW_53 + 1, &"research")).is_not_equal(first)
	assert_int(RandomState.derive_seed(ABOVE_2_POW_53, &"expedition")).is_not_equal(first)


## stream() creates a stream on first use and then returns the same instance.
func test_stream_is_created_once_and_reused() -> void:
	var random := _state_with_seed(42)
	var rng := random.stream(&"research")
	assert_object(random.stream(&"research")).is_same(rng)
	assert_int(rng.seed).is_equal(RandomState.derive_seed(42, &"research"))


## A stream's seed does not depend on the order streams are first requested.
func test_seed_independent_of_request_order() -> void:
	var forward := _state_with_seed(7)
	var backward := _state_with_seed(7)
	for system_id: StringName in SYSTEM_IDS:
		forward.stream(system_id)
	for i: int in range(SYSTEM_IDS.size() - 1, -1, -1):
		backward.stream(SYSTEM_IDS[i])
	for system_id: StringName in SYSTEM_IDS:
		assert_int(backward.stream(system_id).seed).is_equal(forward.stream(system_id).seed)
		var expected := _draw(forward.stream(system_id), 50)
		assert_array(_draw(backward.stream(system_id), 50)).is_equal(expected)


## Same base seed and id give identical sequences; different ids give different ones.
func test_same_id_same_sequence_different_id_different_sequence() -> void:
	var a := _state_with_seed(ABOVE_2_POW_53)
	var b := _state_with_seed(ABOVE_2_POW_53)
	assert_array(_draw(b.stream(&"research"), 100)).is_equal(_draw(a.stream(&"research"), 100))
	var research := _draw(_state_with_seed(5).stream(&"research"), 100)
	var expedition := _draw(_state_with_seed(5).stream(&"expedition"), 100)
	assert_array(expedition).is_not_equal(research)
	var other_seed := _draw(_state_with_seed(6).stream(&"research"), 100)
	assert_array(other_seed).is_not_equal(research)


## to_dict() writes base_seed and every stream's seed and state as decimal strings.
func test_to_dict_writes_strings() -> void:
	var random := _state_with_seed(ABOVE_2_POW_53)
	random.stream(&"research").randi()
	var data := random.to_dict()
	assert_that(data["base_seed"]).is_equal("9007199254740993")
	var streams: Dictionary = data["streams"]
	assert_array(streams.keys()).is_equal(["research"])
	var entry: Dictionary = streams["research"]
	assert_int(typeof(entry["seed"])).is_equal(TYPE_STRING)
	assert_int(typeof(entry["state"])).is_equal(TYPE_STRING)
	assert_that(entry["seed"]).is_equal(str(random.stream(&"research").seed))
	assert_that(entry["state"]).is_equal(str(random.stream(&"research").state))


## A base seed above 2^53 survives JSON exactly; as a JSON number it would not.
func test_seed_above_2_pow_53_survives_json() -> void:
	var as_number: Variant = JSON.parse_string(JSON.stringify({"n": ABOVE_2_POW_53}))["n"]
	assert_int(type_convert(as_number, TYPE_INT)).is_not_equal(ABOVE_2_POW_53)
	var restored := RandomState.from_dict(
		_json_round_trip(_state_with_seed(ABOVE_2_POW_53).to_dict())
	)
	assert_int(restored.base_seed).is_equal(ABOVE_2_POW_53)


## Extreme 64-bit seeds and states are restored exactly.
func test_extreme_values_round_trip() -> void:
	var data := {
		"base_seed": str(-9223372036854775807 - 1),
		"streams": {"edge": {"seed": "9223372036854775807", "state": "-9007199254740993"}},
	}
	var restored := RandomState.from_dict(_json_round_trip(data))
	assert_int(restored.base_seed).is_equal(-9223372036854775807 - 1)
	assert_int(restored.stream(&"edge").seed).is_equal(9223372036854775807)
	assert_int(restored.stream(&"edge").state).is_equal(-9007199254740993)
	assert_dict(restored.to_dict()).is_equal(data)


## After a JSON round trip, the next 1,000 values of every stream match an unsaved copy.
func test_json_round_trip_continues_every_stream() -> void:
	var original := _state_with_seed(ABOVE_2_POW_53)
	for system_id: StringName in SYSTEM_IDS:
		_draw(original.stream(system_id), system_id.length() * 37)
	var restored := RandomState.from_dict(_json_round_trip(original.to_dict()))
	assert_int(restored.base_seed).is_equal(ABOVE_2_POW_53)
	for system_id: StringName in SYSTEM_IDS:
		var restored_rng := restored.stream(system_id)
		assert_int(restored_rng.seed).is_equal(original.stream(system_id).seed)
		var expected := _draw(original.stream(system_id), 1000)
		assert_array(_draw(restored_rng, 1000)).is_equal(expected)


## A legacy save with base_seed as a JSON number and no streams still loads.
func test_from_dict_accepts_number_and_missing_streams() -> void:
	var restored := RandomState.from_dict(_json_round_trip({"base_seed": 77}))
	assert_int(restored.base_seed).is_equal(77)
	assert_dict(restored.to_dict()).is_equal({"base_seed": "77", "streams": {}})


## The scanner flags global calls and ignores RandomNumberGenerator methods and comments.
func test_global_random_scanner_self_check() -> void:
	assert_array(_global_random_calls("var x := randi()")).has_size(1)
	assert_array(_global_random_calls("\trandomize()")).has_size(1)
	assert_array(_global_random_calls("var f := randf_range(0.0, 1.0)")).has_size(1)
	assert_array(_global_random_calls("var x := rng.randi()")).is_empty()
	assert_array(_global_random_calls("var y := _rng.randf_range(0.0, 1.0)")).is_empty()
	assert_array(_global_random_calls("pass  # never randi() here")).is_empty()


## No script under src/ calls the global randi(), randf() or randomize() family.
func test_src_has_no_global_random_calls() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://src", files)
	assert_array(files).is_not_empty()
	var offenders: Array[String] = []
	for path: String in files:
		for hit: String in _global_random_calls(FileAccess.get_file_as_string(path)):
			offenders.append("%s:%s" % [path, hit])
	assert_array(offenders).is_empty()
