## Tests for AddressEntry: the saved shape, a JSON round trip, note rules and validate_dict()
## rejecting malformed keys, bad sources, disagreeing dial fields, a world on a failed dial,
## and notes that are too long or hold control characters.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## technical-architecture.md#data-model
extends GdUnitTestSuite

const KEY: String = "3-17-0-22-9-14-30-5"


func _entry() -> AddressEntry:
	var entry := AddressEntry.create(KEY, AddressEntry.Source.DOCUMENT, &"doc_note")
	entry.world_id = &"world_dead"
	entry.last_outcome = DialOutcome.Kind.BLOCKED
	entry.last_dialed_tick = 77
	entry.note = "Buried? Try again after the dig."
	return entry


## A valid entry's dict with [param key] set to [param value].
func _with(key: String, value: Variant) -> Dictionary:
	var data := _entry().to_dict()
	data[key] = value
	return data


## create() makes a never-dialed entry.
func test_create_is_never_dialed() -> void:
	var entry := AddressEntry.create(KEY, AddressEntry.Source.CONSOLE, &"world_far")
	assert_int(entry.last_outcome).is_equal(-1)
	assert_int(entry.last_dialed_tick).is_equal(-1)
	assert_str(String(entry.world_id)).is_empty()
	(
		assert_dict(entry.to_dict())
		. is_equal(
			{
				"address_key": KEY,
				"source": "console",
				"source_id": "world_far",
				"world_id": "",
				"last_outcome": "",
				"last_dialed_tick": -1,
				"note": "",
			}
		)
	)
	assert_array(AddressEntry.validate_dict(entry.to_dict())).is_empty()


## The saved shape uses lowercase names and survives a JSON round trip.
func test_json_round_trip() -> void:
	var data := _entry().to_dict()
	assert_str(data["source"]).is_equal("document")
	assert_str(data["last_outcome"]).is_equal("blocked")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(AddressEntry.validate_dict(parsed)).is_empty()
	var loaded := AddressEntry.from_dict(parsed)
	assert_dict(loaded.to_dict()).is_equal(data)
	assert_int(loaded.last_outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_int(loaded.source).is_equal(AddressEntry.Source.DOCUMENT)


## Only canonical keys of well-formed addresses are accepted.
func test_is_valid_key() -> void:
	assert_bool(AddressEntry.is_valid_key(KEY)).is_true()
	assert_bool(AddressEntry.is_valid_key("35-0-1-2-3-4-6-5")).is_true()
	for bad: String in [
		"",
		"3-17-0-22-9-14-30",
		"3-17-0-22-9-14-30-5-6",
		"3-17-0-22-9-14-30-3",
		"3-17-0-22-9-14-30-36",
		"3-17-0-22-9-14-30--5",
		"03-17-0-22-9-14-30-5",
		"+3-17-0-22-9-14-30-5",
		"3-17-0-22-9-14-30-x",
		"3 -17-0-22-9-14-30-5",
		"3,17,0,22,9,14,30,5",
	]:
		assert_bool(AddressEntry.is_valid_key(bad)).override_failure_message(bad).is_false()
	assert_array(AddressEntry.glyphs_of(KEY)).is_equal([3, 17, 0, 22, 9, 14, 30, 5])


## Notes up to 140 characters of any script pass; longer ones and control characters fail.
func test_note_errors() -> void:
	assert_array(AddressEntry.note_errors("")).is_empty()
	assert_array(AddressEntry.note_errors("é".repeat(140))).is_empty()
	assert_array(AddressEntry.note_errors("Ωμέγα — dead world 🌑")).is_empty()
	assert_str(AddressEntry.note_errors("a".repeat(141))[0]).contains("141 characters")
	for bad: String in [
		"line\nbreak", "tab\there", "bell" + char(7), "del" + char(0x7f), char(0x85)
	]:
		assert_int(AddressEntry.note_errors(bad).size()).override_failure_message(bad).is_equal(1)


## Each bad field is rejected with a message naming it.
func test_validate_rejects_bad_fields() -> void:
	var cases: Array[Array] = [
		[_with("address_key", "3-17-0-22-9-14-30-3"), "'address_key'"],
		[_with("address_key", 5), "'address_key' is not a string"],
		[_with("source", "radio"), "'source' is not one of"],
		[_with("source_id", ""), "'source_id' is empty"],
		[_with("world_id", 3), "'world_id' is not a string"],
		[_with("last_outcome", "maybe"), "'last_outcome'"],
		[_with("last_dialed_tick", 1.5), "'last_dialed_tick'"],
		[_with("last_dialed_tick", -2), "'last_dialed_tick'"],
		[_with("last_dialed_tick", "77"), "'last_dialed_tick'"],
		[_with("last_dialed_tick", -1), "disagree"],
		[_with("last_outcome", ""), "disagree"],
		[_with("note", "x".repeat(141)), "'note' is 141 characters"],
		[_with("note", "two\nlines"), "'note' has a control character"],
		[_with("note", null), "'note' is not a string"],
	]
	for case: Array in cases:
		var data: Dictionary = case[0]
		var errors: Array[String] = AddressEntry.validate_dict(data)
		assert_int(errors.size()).override_failure_message(str(data)).is_equal(1)
		var expected: String = case[1]
		assert_str(errors[0]).contains(expected)
	var missing := _entry().to_dict()
	missing.erase("note")
	assert_array(AddressEntry.validate_dict(missing)).is_equal(["missing 'note'"])


## A dialed entry has no source id, and knows a world only once it has locked.
func test_dialed_entry_rules() -> void:
	var dialed := AddressEntry.create(KEY, AddressEntry.Source.DIALED, &"")
	dialed.last_outcome = DialOutcome.Kind.LOCK
	dialed.last_dialed_tick = 5
	dialed.world_id = &"world_open"
	assert_array(AddressEntry.validate_dict(dialed.to_dict())).is_empty()
	dialed.last_outcome = DialOutcome.Kind.HOSTILE_LOCK
	assert_array(AddressEntry.validate_dict(dialed.to_dict())).is_empty()
	for failed: DialOutcome.Kind in [
		DialOutcome.Kind.NO_GATE, DialOutcome.Kind.BLOCKED, DialOutcome.Kind.ORIGIN_REJECTED
	]:
		dialed.last_outcome = failed
		var errors: Array[String] = AddressEntry.validate_dict(dialed.to_dict())
		assert_str(errors[0]).contains("has not locked")
	dialed.world_id = &""
	assert_array(AddressEntry.validate_dict(dialed.to_dict())).is_empty()
	dialed.source_id = &"doc_note"
	assert_str(AddressEntry.validate_dict(dialed.to_dict())[0]).contains("'source_id' is not empty")
