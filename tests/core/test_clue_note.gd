## Tests for ClueNote: the saved shape, JSON round trips and validate_dict() on tags (player
## text: count, length and control characters only), links and board positions.
## Bible: gate-and-address-spec.md#player-tools, technical-architecture.md#data-model
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")


func _sample() -> ClueNote:
	var links: Array[StringName] = [&"clue_0002", &"clue_0003"]
	var tags: Array[String] = ["P3X-118", "ÁGUA", "a b"]
	return Fixture.note(links, tags)


func _assert_rejects(key: String, value: Variant, expected: String) -> void:
	var data := _sample().to_dict()
	data[key] = value
	var errors := ClueNote.validate_dict(data)
	var label := "%s = %s: %s" % [key, str(value), str(errors)]
	var found := errors.any(func(error: String) -> bool: return error.contains(expected))
	assert_bool(found).override_failure_message(label).is_true()


func _tags(count: int, length: int) -> Array[String]:
	var tags: Array[String] = []
	for index: int in count:
		tags.append("x".repeat(length))
	return tags


## The saved shape: a bool, tag and link strings and the position as [x, y] ints.
func test_to_dict_shape() -> void:
	(
		assert_dict(_sample().to_dict())
		. is_equal(
			{
				"is_suspect": true,
				"tags": ["P3X-118", "ÁGUA", "a b"],
				"links": ["clue_0002", "clue_0003"],
				"board_position": [120, 3400],
			}
		)
	)


## A JSON round trip rebuilds an equal note with a Vector2i position and StringName links.
func test_json_round_trip() -> void:
	var data := _sample().to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(ClueNote.validate_dict(parsed)).is_empty()
	var restored := ClueNote.from_dict(parsed)
	assert_dict(restored.to_dict()).is_equal(data)
	assert_that(restored.board_position).is_equal(Vector2i(120, 3400))
	assert_int(typeof(restored.links[0])).is_equal(TYPE_STRING_NAME)


## A new note is the default; any change makes it not the default.
func test_is_default() -> void:
	assert_bool(ClueNote.new().is_default()).is_true()
	assert_bool(_sample().is_default()).is_false()
	var moved := ClueNote.new()
	moved.board_position = Vector2i(1, 0)
	assert_bool(moved.is_default()).is_false()


## Up to MAX_TAGS tags of up to MAX_TAG_LENGTH characters are accepted, also non-ASCII.
func test_accepts_tags_at_limits() -> void:
	var data := _sample().to_dict()
	data["tags"] = _tags(ClueNote.MAX_TAGS, ClueNote.MAX_TAG_LENGTH)
	assert_array(ClueNote.validate_dict(data)).is_empty()
	data["tags"] = ["É".repeat(ClueNote.MAX_TAG_LENGTH), "星図"]
	assert_array(ClueNote.validate_dict(data)).is_empty()


## Too many, too long, empty or non-string tags and tags with control characters are
## rejected.
func test_rejects_bad_tags() -> void:
	_assert_rejects("tags", _tags(ClueNote.MAX_TAGS + 1, 1), "9 tags, more than 8")
	_assert_rejects("tags", _tags(1, ClueNote.MAX_TAG_LENGTH + 1), "tag 0 is not 1 to 32")
	_assert_rejects("tags", [""], "tag 0 is not 1 to 32")
	_assert_rejects("tags", [3], "tag 0 is not a string")
	_assert_rejects("tags", "x", "'tags' is not an array")
	for bad: String in ["a\nb", "\t", "x\u0001", "del\u007f", "c1\u0085"]:
		_assert_rejects("tags", ["ok", bad], "tag 1 has a control character")


## Links must be distinct non-empty strings.
func test_rejects_bad_links() -> void:
	_assert_rejects("links", [""], "link 0 is not a clue id")
	_assert_rejects("links", [4], "link 0 is not a clue id")
	_assert_rejects("links", ["clue_0002", "clue_0002"], "link 1 repeats")
	_assert_rejects("links", {}, "'links' is not an array")


## Positions must be two whole numbers from 0 to 4000.
func test_board_position_range() -> void:
	var data := _sample().to_dict()
	for good: Array in [[0, 0], [4000, 4000], [4000.0, 0.0]]:
		data["board_position"] = good
		assert_array(ClueNote.validate_dict(data)).override_failure_message(str(good)).is_empty()
	for bad: Variant in [[-1, 0], [0, 4001], [1.5, 2], [1], [1, 2, 3], "1,2", null, ["1", 2]]:
		_assert_rejects("board_position", bad, "'board_position'")


## is_suspect must be a bool.
func test_rejects_non_bool_suspect() -> void:
	_assert_rejects("is_suspect", 1, "'is_suspect'")
	_assert_rejects("is_suspect", null, "'is_suspect'")
