## Tests for SaveService with the Archive and the Address Book: an exact round trip with
## documents received and read and four book entries, and hand-edited sections failing cleanly.
## Each test uses its own instance pointed at a unique temporary user:// folder.
## Bible: technical-architecture.md#save-system (round-trip test),
## gate-and-address-spec.md#the-dial-console (Address Book)
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")

var _service: SaveServiceScript


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://test_saves_docs_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]


func after_test() -> void:
	var dir := DirAccess.open(_service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


func _entry(key: String, source: AddressEntry.Source, source_id: StringName) -> AddressEntry:
	return AddressEntry.create(key, source, source_id)


## Three documents (two read) and four book entries of every source, at clock tick 2000.
func _sample_state() -> GameState:
	var state := GameState.new_game(20261023, BalanceConfig.new())
	state.clock.tick = 2000
	state.archive.add(&"doc_survey_note", 0)
	state.archive.add(&"doc_survey_rubbing", 0)
	state.archive.add(&"doc_dossier_1961", 1440)
	state.archive.read[&"doc_survey_note"] = true
	state.archive.read[&"doc_survey_rubbing"] = true
	var from_doc := _entry("0-13-7-21-30-2-18-5", AddressEntry.Source.DOCUMENT, &"doc_survey_note")
	from_doc.world_id = &"world_dead"
	from_doc.last_outcome = DialOutcome.Kind.LOCK
	from_doc.last_dialed_tick = 120
	from_doc.note = "Dead, safe and quiet — «ok»."
	var from_console := _entry("1-2-3-4-6-7-8-5", AddressEntry.Source.CONSOLE, &"world_dead")
	var dialed := _entry("9-10-11-12-13-14-15-5", AddressEntry.Source.DIALED, &"")
	dialed.last_outcome = DialOutcome.Kind.BLOCKED
	dialed.last_dialed_tick = 1999
	var locked := _entry("20-21-22-23-24-25-26-5", AddressEntry.Source.DIALED, &"")
	locked.last_outcome = DialOutcome.Kind.HOSTILE_LOCK
	locked.last_dialed_tick = 2000
	locked.world_id = &"world_guarded"
	state.address_book.entries.assign([locked, dialed, from_console, from_doc])
	return state


## Save then load reproduces the state's to_dict() exactly.
func test_round_trip_is_identical() -> void:
	var state := _sample_state()
	var original := state.to_dict()
	assert_bool(_service.save_game(state, &"docs_round_trip").is_ok).is_true()
	var result: Result = _service.load_game(&"docs_round_trip")
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	assert_dict(loaded.to_dict()).is_equal(original)
	assert_array(loaded.archive.received).is_equal(state.archive.received)
	assert_int(loaded.address_book.entries.size()).is_equal(4)
	assert_str(loaded.address_book.entries[3].note).is_equal("Dead, safe and quiet — «ok».")


func _repeat_first_entry(book: Dictionary) -> void:
	var entries: Array = book["entries"]
	entries.append(entries[0])


func _world_on_never_dialed_entry(book: Dictionary) -> void:
	var entries: Array = book["entries"]
	var entry: Dictionary = entries[1]
	entry["last_outcome"] = ""
	entry["last_dialed_tick"] = -1
	entry["world_id"] = "world_x"


## Hand-edited Archive and Address Book data fails with &"invalid_state".
func test_hand_edited_sections_fail() -> void:
	var cases: Array[Array] = [
		["archive", func(d: Dictionary) -> void: d["read"]["doc_ghost"] = true],
		["archive", func(d: Dictionary) -> void: d["received_tick"]["doc_dossier_1961"] = 2001],
		["address_book", _repeat_first_entry],
		["address_book", func(d: Dictionary) -> void: d["entries"][0]["address_key"] = "1-2"],
		["address_book", func(d: Dictionary) -> void: d["entries"][1]["note"] = "x".repeat(141)],
		["address_book", _world_on_never_dialed_entry],
		["address_book", func(d: Dictionary) -> void: d["entries"][1]["last_dialed_tick"] = 2001],
	]
	for case: Array in cases:
		assert_bool(_service.save_game(_sample_state(), &"edited").is_ok).is_true()
		var path: String = _service.slot_path(&"edited")
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var state_data: Dictionary = data["state"]
		var edit: Callable = case[1]
		edit.call(state_data[case[0]])
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var result: Result = _service.load_game(&"edited")
		assert_str(String(result.error_code)).override_failure_message(str(case)).is_equal(
			"invalid_state"
		)
