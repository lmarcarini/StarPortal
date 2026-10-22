## Scans the code under src/gate/ for what pure rules must not use: autoloads, global or
## reseeded randomness, wall-clock time and Nodes; and checks GateAddress depends on no content.
## A local, seeded RandomNumberGenerator is allowed (the world and clue generators take one).
## Bible: technical-architecture.md#code-standards,
## technical-architecture.md#determinism-and-numbers
extends GdUnitTestSuite

const GATE_ROOT: String = "res://src/gate"
const GATE_ADDRESS_PATH: String = "res://src/gate/gate_address.gd"
const FORBIDDEN: Array[String] = [
	"EventBus",
	"Settings",
	"Registry",
	"SimClock",
	"SaveService",
	"InputService",
	"Time.",
	"OS.",
	"get_tree",
	"Node",
]
## Global random functions called bare (not as a method after "." or as part of a longer name);
## rng.randi() is fine, randi() is not.
const GLOBAL_RANDOM_PATTERN: String = (
	"(?<![.\\w])" + "(randi|randf|randi_range|randf_range|randfn|randomize|seed)\\s*\\("
)
## Reseeding any generator from time, and Array methods that draw from the global generator.
const METHOD_RANDOM_PATTERN: String = "\\.(randomize|shuffle|pick_random)\\s*\\("
const CONTENT_NAMES: Array[String] = ["Def", "BalanceConfig"]


func _gate_scripts() -> Array[String]:
	var paths: Array[String] = []
	for entry: String in DirAccess.get_files_at(GATE_ROOT):
		if entry.ends_with(".gd"):
			paths.append(GATE_ROOT.path_join(entry))
	return paths


## Every forbidden random call in [param source], as matched text.
func _random_uses(source: String) -> Array[String]:
	var uses: Array[String] = []
	for pattern: String in [GLOBAL_RANDOM_PATTERN, METHOD_RANDOM_PATTERN]:
		var regex := RegEx.create_from_string(pattern)
		for found: RegExMatch in regex.search_all(source):
			uses.append(found.get_string())
	return uses


## Every gate script is free of autoloads, wall-clock time and Nodes.
func test_gate_scripts_are_pure() -> void:
	var paths: Array[String] = _gate_scripts()
	assert_int(paths.size()).is_greater_equal(4)
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN:
			(
				assert_bool(source.contains(word))
				. override_failure_message("%s uses %s" % [path, word])
				. is_false()
			)


## No gate script uses global randomness or reseeds a generator.
func test_gate_scripts_use_only_seeded_randomness() -> void:
	for path: String in _gate_scripts():
		var uses: Array[String] = _random_uses(FileAccess.get_file_as_string(path))
		assert_array(uses).override_failure_message("%s uses %s" % [path, uses]).is_empty()


## The randomness rule catches each forbidden form and allows calls on a local generator.
func test_randomness_rule_catches_each_form() -> void:
	var forbidden: Array[String] = [
		"randi()",
		"var x := randf()",
		"randi_range(0, 3)",
		"(randf_range(0.0, 1.0))",
		"randfn(0.0, 1.0)",
		"randomize()",
		"seed(42)",
		"rng.randomize()",
		"values.shuffle()",
		"values.pick_random()",
	]
	for line: String in forbidden:
		assert_array(_random_uses(line)).override_failure_message(line).is_not_empty()
	var allowed: Array[String] = [
		"var rng := RandomNumberGenerator.new()",
		"rng.seed = seed",
		"rng.randi_range(0, 3)",
		"rng.randf()",
		"_reseed(1)",
		"static func generate(seed: int) -> void:",
	]
	for line: String in allowed:
		assert_array(_random_uses(line)).override_failure_message(line).is_empty()


## GateAddress is just ints: it names no definition class.
func test_gate_address_has_no_content_dependency() -> void:
	var source: String = FileAccess.get_file_as_string(GATE_ADDRESS_PATH)
	for word: String in CONTENT_NAMES:
		assert_bool(source.contains(word)).override_failure_message(word).is_false()
