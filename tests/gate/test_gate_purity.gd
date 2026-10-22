## Scans the address code under src/gate/ for what pure rules must not use: autoloads, global or
## unseeded randomness, wall-clock time and Nodes; and checks GateAddress depends on no content.
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
	"randi",
	"randf",
	"RandomNumberGenerator",
	"Time.",
	"OS.",
	"get_tree",
	"Node",
]
const CONTENT_NAMES: Array[String] = ["Def", "BalanceConfig"]


func _gate_scripts() -> Array[String]:
	var paths: Array[String] = []
	for entry: String in DirAccess.get_files_at(GATE_ROOT):
		if entry.ends_with(".gd"):
			paths.append(GATE_ROOT.path_join(entry))
	return paths


## Every gate script is free of autoloads, randomness, wall-clock time and Nodes.
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


## GateAddress is just ints: it names no definition class.
func test_gate_address_has_no_content_dependency() -> void:
	var source: String = FileAccess.get_file_as_string(GATE_ADDRESS_PATH)
	for word: String in CONTENT_NAMES:
		assert_bool(source.contains(word)).override_failure_message(word).is_false()
