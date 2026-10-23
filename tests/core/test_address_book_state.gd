## Tests for AddressBookState: find(), search by glyphs, recording dials (new entries on top, a
## world only on a lock), the saved shape and validate_dict() rejecting bad shapes and repeated
## addresses.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## technical-architecture.md#data-model
extends GdUnitTestSuite

const KEY_A: String = "3-17-0-22-9-14-30-5"
const KEY_B: String = "1-2-3-4-6-7-8-5"
const KEY_C: String = "17-3-10-11-12-13-0-5"


func _book() -> AddressBookState:
	var book := AddressBookState.new()
	book.entries.append(AddressEntry.create(KEY_A, AddressEntry.Source.DOCUMENT, &"doc_note"))
	book.entries.append(AddressEntry.create(KEY_B, AddressEntry.Source.CONSOLE, &"world_far"))
	book.entries.append(AddressEntry.create(KEY_C, AddressEntry.Source.DIALED, &""))
	return book


func _log_entry(key: String, outcome: DialOutcome.Kind, world: StringName) -> DialLogEntry:
	var glyphs: Array[int] = AddressEntry.glyphs_of(key)
	var origin: int = glyphs.pop_back()
	var entry := DialLogEntry.new()
	entry.tick = 40
	entry.address = GateAddress.create(glyphs, origin)
	entry.outcome = outcome
	entry.world_id = world
	return entry


## find() returns the entry with that key, or null.
func test_find() -> void:
	var book := _book()
	assert_str(book.find(KEY_B).address_key).is_equal(KEY_B)
	assert_object(book.find("0-1-2-3-4-6-7-5")).is_null()


## search_by_glyphs() returns the entries holding every given glyph, in book order.
func test_search_by_glyphs() -> void:
	var book := _book()
	var keys := func(found: Array[AddressEntry]) -> Array[String]:
		var result: Array[String] = []
		for entry: AddressEntry in found:
			result.append(entry.address_key)
		return result
	assert_array(keys.call(book.search_by_glyphs([17, 3]))).is_equal([KEY_A, KEY_C])
	assert_array(keys.call(book.search_by_glyphs([3]))).is_equal([KEY_A, KEY_B, KEY_C])
	assert_array(keys.call(book.search_by_glyphs([4, 7]))).is_equal([KEY_B])
	assert_array(keys.call(book.search_by_glyphs([17, 4]))).is_empty()
	assert_array(keys.call(book.search_by_glyphs([]))).is_equal([KEY_A, KEY_B, KEY_C])


## A new address goes on top as DIALED with its outcome and tick; a failed dial records no
## world.
func test_record_dial_adds_new_address_on_top() -> void:
	var book := _book()
	var entry := book.record_dial(_log_entry("0-1-2-4-6-7-8-5", DialOutcome.Kind.BLOCKED, &"w"))
	assert_int(book.entries.size()).is_equal(4)
	assert_object(book.entries[0]).is_same(entry)
	assert_int(entry.source).is_equal(AddressEntry.Source.DIALED)
	assert_str(String(entry.source_id)).is_empty()
	assert_int(entry.last_outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_int(entry.last_dialed_tick).is_equal(40)
	assert_str(String(entry.world_id)).is_empty()


## A known address is updated in place: source, note and position kept; a lock records the
## world, and a later failure does not clear it.
func test_record_dial_updates_known_address() -> void:
	var book := _book()
	book.entries[1].note = "from the far console"
	book.record_dial(_log_entry(KEY_B, DialOutcome.Kind.LOCK, &"world_far_b"))
	var entry: AddressEntry = book.entries[1]
	assert_int(book.entries.size()).is_equal(3)
	assert_str(entry.address_key).is_equal(KEY_B)
	assert_int(entry.source).is_equal(AddressEntry.Source.CONSOLE)
	assert_str(entry.note).is_equal("from the far console")
	assert_str(String(entry.world_id)).is_equal("world_far_b")
	book.record_dial(_log_entry(KEY_B, DialOutcome.Kind.BLOCKED, &"world_far_b"))
	assert_int(entry.last_outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_str(String(entry.world_id)).is_equal("world_far_b")


## The saved shape is a list of entries, and a JSON round trip is equal.
func test_json_round_trip() -> void:
	var book := _book()
	book.record_dial(_log_entry(KEY_C, DialOutcome.Kind.HOSTILE_LOCK, &"world_guarded"))
	var data := book.to_dict()
	assert_array(data.keys()).is_equal(["entries"])
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_array(AddressBookState.validate_dict(parsed)).is_empty()
	assert_dict(AddressBookState.from_dict(parsed).to_dict()).is_equal(data)
	assert_array(AddressBookState.validate_dict(AddressBookState.new().to_dict())).is_empty()


## Bad shapes, bad entries and repeated addresses are rejected.
func test_validate_rejects_bad_data() -> void:
	assert_array(AddressBookState.validate_dict({})).is_equal(["missing 'entries'"])
	assert_array(AddressBookState.validate_dict({"entries": {}})).is_equal(
		["'entries' is not an array"]
	)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_book().to_dict()))
	var entries: Array = data["entries"]
	entries.append(3)
	entries.append(_book().entries[0].to_dict())
	var bad_entry := _book().entries[2].to_dict()
	bad_entry["address_key"] = "1-1-1-1-1-1-1-1"
	entries.append(bad_entry)
	(
		assert_array(AddressBookState.validate_dict(data))
		. is_equal(
			[
				"entries 3 is not an object",
				"entries 4 repeats the address of entries 0",
				"entries 5: 'address_key' is not the key of a well-formed address",
			]
		)
	)
