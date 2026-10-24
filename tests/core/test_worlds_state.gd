## Tests for WorldsState: status lookup, the galaxy seed as a decimal string, round trips
## and validate_dict() errors.
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system
extends GdUnitTestSuite

## A seed above 2^53, which a JSON number cannot hold exactly.
const BIG_SEED: int = -7230724724541804083


func _sample() -> WorldsState:
	var worlds := WorldsState.new()
	worlds.galaxy_seed = BIG_SEED
	worlds.generator_version = 1
	worlds.statuses[&"abydos"] = WorldsState.WorldStatus.LOCKED
	worlds.statuses[&"p3x_118"] = WorldsState.WorldStatus.LOCKED
	worlds.consoles_read[&"abydos"] = true
	return worlds


## status_of() returns the stored status, and UNKNOWN for any other world.
func test_status_of() -> void:
	var worlds := _sample()
	assert_int(worlds.status_of(&"abydos")).is_equal(WorldsState.WorldStatus.LOCKED)
	assert_int(worlds.status_of(&"chulak")).is_equal(WorldsState.WorldStatus.UNKNOWN)
	assert_int(WorldsState.new().status_of(&"abydos")).is_equal(WorldsState.WorldStatus.UNKNOWN)


## The seed is a decimal string, statuses are lowercase names keyed by world id.
func test_dict_shape() -> void:
	(
		assert_dict(_sample().to_dict())
		. is_equal(
			{
				"galaxy_seed": "-7230724724541804083",
				"generator_version": 1,
				"statuses": {"abydos": "locked", "p3x_118": "locked"},
				"consoles_read": {"abydos": true},
			}
		)
	)


## A JSON round trip keeps the 64-bit seed exact and the statuses typed.
func test_json_round_trip() -> void:
	var data := _sample().to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(WorldsState.validate_dict(parsed)).is_empty()
	var restored := WorldsState.from_dict(parsed)
	assert_int(restored.galaxy_seed).is_equal(BIG_SEED)
	assert_int(typeof(restored.generator_version)).is_equal(TYPE_INT)
	assert_int(typeof(restored.statuses.keys()[0])).is_equal(TYPE_STRING_NAME)
	assert_dict(restored.to_dict()).is_equal(data)


## validate_dict rejects bad seeds, versions and statuses, including a stored "unknown".
func test_validate_errors() -> void:
	var good := _sample().to_dict()
	var cases: Array[Array] = [
		["galaxy_seed", 12, "galaxy_seed"],
		["galaxy_seed", "+12", "galaxy_seed"],
		["galaxy_seed", "99999999999999999999", "galaxy_seed"],
		["generator_version", -1, "generator_version"],
		["generator_version", 1.5, "generator_version"],
		["generator_version", "1", "generator_version"],
		["statuses", [], "'statuses' is not an object"],
		["statuses", {"abydos": "unknown"}, "status of 'abydos'"],
		["statuses", {"abydos": "probed"}, "status of 'abydos'"],
		["statuses", {"abydos": 1}, "status of 'abydos'"],
		["statuses", {"": "locked"}, "empty world id"],
		["consoles_read", [], "'consoles_read' is not an object"],
		["consoles_read", {"abydos": false}, "consoles_read of 'abydos'"],
		["consoles_read", {"abydos": 1}, "consoles_read of 'abydos'"],
		["consoles_read", {"": true}, "empty world id"],
	]
	for case: Array in cases:
		var data := good.duplicate(true)
		data[case[0]] = case[1]
		var errors := "\n".join(WorldsState.validate_dict(data))
		assert_str(errors).override_failure_message(str(case)).contains(str(case[2]))
	for key: String in good:
		var missing := good.duplicate(true)
		missing.erase(key)
		assert_array(WorldsState.validate_dict(missing)).contains(["missing '%s'" % key])
