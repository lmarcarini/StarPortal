## Tests for ArchiveState: the documents held, in arrival order, with their arrival ticks and
## read marks; the saved shape, a JSON round trip, and validate_dict() rejecting bad shapes,
## repeated ids, unknown documents in "read" and bad ticks.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## technical-architecture.md#data-model
extends GdUnitTestSuite


func _sample() -> ArchiveState:
	var archive := ArchiveState.new()
	archive.add(&"doc_note", 10)
	archive.add(&"doc_rubbing", 10)
	archive.add(&"doc_dossier", 9007199254740992)
	archive.read[&"doc_note"] = true
	archive.read[&"doc_dossier"] = false
	return archive


## add() keeps arrival order and ticks; nothing is read until marked.
func test_add_and_queries() -> void:
	var archive := _sample()
	assert_array(archive.received).is_equal([&"doc_note", &"doc_rubbing", &"doc_dossier"])
	assert_int(archive.received_tick[&"doc_rubbing"]).is_equal(10)
	assert_bool(archive.has_document(&"doc_rubbing")).is_true()
	assert_bool(archive.has_document(&"doc_other")).is_false()
	assert_bool(archive.is_read(&"doc_note")).is_true()
	assert_bool(archive.is_read(&"doc_rubbing")).is_false()
	assert_bool(archive.is_read(&"doc_dossier")).is_false()


## The saved shape uses string ids and keeps order.
func test_to_dict_shape() -> void:
	(
		assert_dict(_sample().to_dict())
		. is_equal(
			{
				"received": ["doc_note", "doc_rubbing", "doc_dossier"],
				"read": {"doc_note": true, "doc_dossier": false},
				"received_tick":
				{"doc_note": 10, "doc_rubbing": 10, "doc_dossier": 9007199254740992},
			}
		)
	)


## A JSON round trip validates and rebuilds an equal Archive, ticks as ints.
func test_json_round_trip() -> void:
	var data := _sample().to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(ArchiveState.validate_dict(parsed)).is_empty()
	var loaded := ArchiveState.from_dict(parsed)
	assert_dict(loaded.to_dict()).is_equal(data)
	assert_int(typeof(loaded.received_tick[&"doc_note"])).is_equal(TYPE_INT)
	assert_array(ArchiveState.validate_dict(ArchiveState.new().to_dict())).is_empty()


## Each bad shape is rejected with a message naming what is wrong.
func test_validate_rejects_bad_data() -> void:
	var cases: Array[Array] = [
		[{"read": {}, "received_tick": {}}, "missing 'received'"],
		[{"received": [], "received_tick": {}}, "missing 'read'"],
		[{"received": [], "read": {}}, "missing 'received_tick'"],
		[{"received": {}, "read": {}, "received_tick": {}}, "'received' is not an array"],
		[{"received": [""], "read": {}, "received_tick": {"": 1}}, "not a non-empty string"],
		[{"received": [3], "read": {}, "received_tick": {}}, "not a non-empty string"],
		[{"received": ["a", "a"], "read": {}, "received_tick": {"a": 1}}, "repeats 'a'"],
		[{"received": ["a"], "read": [], "received_tick": {"a": 1}}, "'read' is not an object"],
		[{"received": ["a"], "read": {"b": true}, "received_tick": {"a": 1}}, "'b', which is not"],
		[{"received": ["a"], "read": {"a": 1}, "received_tick": {"a": 1}}, "not a bool"],
		[{"received": ["a"], "read": {}, "received_tick": 4}, "'received_tick' is not an object"],
		[{"received": ["a"], "read": {}, "received_tick": {}}, "received_tick is missing 'a'"],
		[{"received": ["a"], "read": {}, "received_tick": {"a": 1, "b": 1}}, "'b', which is not"],
		[{"received": ["a"], "read": {}, "received_tick": {"a": -1}}, "whole number"],
		[{"received": ["a"], "read": {}, "received_tick": {"a": 1.5}}, "whole number"],
		[{"received": ["a"], "read": {}, "received_tick": {"a": "1"}}, "whole number"],
		[
			{"received": ["a"], "read": {}, "received_tick": {"a": 9007199254740994.0}},
			"whole number"
		],
	]
	for case: Array in cases:
		var data: Dictionary = case[0]
		var expected: String = case[1]
		var errors: Array[String] = ArchiveState.validate_dict(data)
		assert_int(errors.size()).override_failure_message(str(data)).is_equal(1)
		assert_str(errors[0]).contains(expected)


## from_dict() skips unreadable values instead of failing.
func test_from_dict_skips_unreadable_values() -> void:
	var loaded := ArchiveState.from_dict({"received": 3, "read": {"a": 1}, "received_tick": []})
	assert_array(loaded.received).is_empty()
	assert_dict(loaded.read).is_empty()
	assert_dict(loaded.received_tick).is_empty()
